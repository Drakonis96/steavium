import AppKit
import Foundation

// MARK: - Update state

enum UpdateStatus: Equatable {
    case idle
    case checking
    case noUpdate
    case available(version: String, notes: String)
    case downloading(progress: Double)
    case installing
    case installed(version: String)
    case failed(message: String)

    static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.checking, .checking),
             (.noUpdate, .noUpdate),
             (.installing, .installing):
            return true
        case (.available(let lv, _), .available(let rv, _)):
            return lv == rv
        case (.downloading(let lp), .downloading(let rp)):
            return lp == rp
        case (.installed(let lv), .installed(let rv)):
            return lv == rv
        case (.failed(let lm), .failed(let rm)):
            return lm == rm
        default:
            return false
        }
    }
}

// MARK: - GitHub release model

private struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case assets
    }
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
    }
}

// MARK: - AppUpdater

@MainActor
final class AppUpdater: ObservableObject {

    static let currentVersion = "0.0.5"
    static let repoOwner = "Drakonis96"
    static let repoName = "steavium"

    @Published var status: UpdateStatus = .idle

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API

    /// Check GitHub for a newer release than the current version.
    func checkForUpdate() async {
        guard status != .checking else { return }
        status = .checking

        do {
            let release = try await fetchLatestRelease()
            let remoteVersion = release.tagName
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "^v", with: "", options: .regularExpression)

            if compareVersions(remote: remoteVersion, local: Self.currentVersion) == .orderedDescending {
                let notes = release.body ?? ""
                status = .available(version: remoteVersion, notes: notes)
            } else {
                status = .noUpdate
            }
        } catch {
            status = .failed(message: error.localizedDescription)
        }
    }

    /// Download the DMG from the latest release and install it.
    func downloadAndInstall() async {
        guard case .available(let version, _) = status else { return }

        do {
            status = .downloading(progress: 0)

            let release = try await fetchLatestRelease()

            guard let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) else {
                status = .failed(message: "No DMG asset found in release.")
                return
            }

            guard let url = URL(string: dmgAsset.browserDownloadURL) else {
                status = .failed(message: "Invalid download URL.")
                return
            }

            let dmgPath = try await downloadDMG(url: url, expectedSize: dmgAsset.size)
            status = .installing
            try await installFromDMG(dmgPath: dmgPath)
            status = .installed(version: version)
        } catch {
            status = .failed(message: error.localizedDescription)
        }
    }

    /// Relaunch the app after installing an update.
    func relaunchApp() {
        guard let appPath = currentAppBundlePath() else { return }

        let pid = ProcessInfo.processInfo.processIdentifier

        // Spawn a background shell that waits for the current process to
        // exit, then opens the freshly-installed app.
        let script = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.1; done
        open "\(appPath)"
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", script]
        try? task.run()

        // Terminate immediately – the watcher shell will relaunch once
        // this process is gone.
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Private helpers

    private func fetchLatestRelease() async throws -> GitHubRelease {
        let urlString = "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    private func downloadDMG(url: URL, expectedSize: Int) async throws -> URL {
        let (asyncBytes, response) = try await session.bytes(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let totalSize = httpResponse.expectedContentLength > 0
            ? Int(httpResponse.expectedContentLength)
            : expectedSize

        let tempDir = FileManager.default.temporaryDirectory
        let dmgPath = tempDir.appendingPathComponent("Steavium-Update.dmg")

        // Remove previous download if any
        try? FileManager.default.removeItem(at: dmgPath)

        var data = Data()
        data.reserveCapacity(totalSize)

        var downloaded = 0
        for try await byte in asyncBytes {
            data.append(byte)
            downloaded += 1
            if downloaded % (256 * 1024) == 0 || downloaded == totalSize {
                let progress = totalSize > 0 ? Double(downloaded) / Double(totalSize) : 0
                status = .downloading(progress: min(progress, 1.0))
            }
        }

        try data.write(to: dmgPath)
        return dmgPath
    }

    private func installFromDMG(dmgPath: URL) async throws {
        // Mount the DMG
        let mountPoint = FileManager.default.temporaryDirectory
            .appendingPathComponent("SteaviumMount-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)

        let mountProcess = Process()
        mountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        mountProcess.arguments = [
            "attach", dmgPath.path,
            "-mountpoint", mountPoint.path,
            "-nobrowse",
            "-quiet"
        ]
        try mountProcess.run()
        mountProcess.waitUntilExit()

        guard mountProcess.terminationStatus == 0 else {
            throw NSError(domain: "AppUpdater", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to mount DMG."])
        }

        defer {
            // Detach the DMG
            let detach = Process()
            detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            detach.arguments = ["detach", mountPoint.path, "-quiet"]
            try? detach.run()
            detach.waitUntilExit()
            // Cleanup temp DMG
            try? FileManager.default.removeItem(at: dmgPath)
        }

        // Find Steavium.app in the mounted volume
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)
        guard let sourceApp = contents.first(where: { $0.lastPathComponent == "Steavium.app" }) else {
            throw NSError(domain: "AppUpdater", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Steavium.app not found in DMG."])
        }

        // Determine current app location
        guard let currentPath = currentAppBundlePath() else {
            throw NSError(domain: "AppUpdater", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot determine current app location."])
        }

        let currentAppURL = URL(fileURLWithPath: currentPath)
        let backupURL = currentAppURL
            .deletingLastPathComponent()
            .appendingPathComponent("Steavium-old.app")

        // Backup → Replace
        try? fm.removeItem(at: backupURL)
        try fm.moveItem(at: currentAppURL, to: backupURL)

        do {
            try fm.copyItem(at: sourceApp, to: currentAppURL)
            // Remove backup on success
            try? fm.removeItem(at: backupURL)
        } catch {
            // Restore backup on failure
            try? fm.moveItem(at: backupURL, to: currentAppURL)
            throw error
        }
    }

    private func currentAppBundlePath() -> String? {
        let bundlePath = Bundle.main.bundlePath
        // If running from an .app bundle, use that
        if bundlePath.hasSuffix(".app") {
            return bundlePath
        }
        // Fallback: try common install location
        let applicationsPath = "/Applications/Steavium.app"
        if FileManager.default.fileExists(atPath: applicationsPath) {
            return applicationsPath
        }
        return nil
    }

    /// Compare two semantic version strings (e.g. "0.0.2" vs "0.0.1").
    private func compareVersions(remote: String, local: String) -> ComparisonResult {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }

        let maxCount = max(remoteParts.count, localParts.count)
        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return .orderedDescending }
            if r < l { return .orderedAscending }
        }
        return .orderedSame
    }
}
