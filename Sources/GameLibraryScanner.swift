import Foundation

struct SteamAppManifest: Sendable, Equatable {
    let appID: Int
    let name: String
    let installDirectoryName: String

    static func parse(contents: String) throws -> SteamAppManifest? {
        let document = try ValveKeyValueDocument.parse(contents)
        guard let appStateValue = document.value(at: ["AppState"]),
              case .object(let appStateEntries) = appStateValue else {
            return nil
        }

        let appState = ValveKeyValueDocument(entries: appStateEntries)
        guard let appIDText = appState.string(at: ["appid"]),
              let appID = Int(appIDText),
              let name = appState.string(at: ["name"]),
              let installDirectoryName = appState.string(at: ["installdir"]) else {
            return nil
        }

        return SteamAppManifest(
            appID: appID,
            name: name,
            installDirectoryName: installDirectoryName
        )
    }
}

enum GameLibraryScanner {
    static func steamRoot(steamExecutablePath: String) -> URL {
        URL(fileURLWithPath: steamExecutablePath).deletingLastPathComponent()
    }

    static func discoverInstalledGames(
        steamRoot: URL,
        fileManager: FileManager = .default
    ) -> [InstalledGame] {
        let steamAppsPath = steamRoot.appendingPathComponent("steamapps", isDirectory: true)
        guard let manifestURLs = try? fileManager.contentsOfDirectory(
            at: steamAppsPath,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let manifests = manifestURLs
            .filter { $0.lastPathComponent.hasPrefix("appmanifest_") && $0.pathExtension.lowercased() == "acf" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var games: [InstalledGame] = []
        for manifestURL in manifests {
            guard let content = try? String(contentsOf: manifestURL, encoding: .utf8) else {
                continue
            }

            guard let manifest = try? SteamAppManifest.parse(contents: content) else {
                continue
            }

            let installDirectory = steamAppsPath
                .appendingPathComponent("common", isDirectory: true)
                .appendingPathComponent(manifest.installDirectoryName, isDirectory: true)

            let candidates = executableCandidates(
                in: installDirectory,
                gameName: manifest.name,
                fileManager: fileManager
            )

            let game = InstalledGame(
                appID: manifest.appID,
                name: manifest.name,
                installDirectoryPath: installDirectory.path,
                executableCandidates: candidates,
                defaultExecutableRelativePath: candidates.first?.relativePath
            )
            games.append(game)
        }

        return games.sorted {
            if $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedSame {
                return $0.appID < $1.appID
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    static func locateLocalConfigFiles(
        steamRoot: URL,
        fileManager: FileManager = .default
    ) -> [URL] {
        let userDataPath = steamRoot.appendingPathComponent("userdata", isDirectory: true)
        guard let userDirectories = try? fileManager.contentsOfDirectory(
            at: userDataPath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let configs = userDirectories.compactMap { userDir -> URL? in
            let localConfig = userDir
                .appendingPathComponent("config", isDirectory: true)
                .appendingPathComponent("localconfig.vdf")
            return fileManager.fileExists(atPath: localConfig.path) ? localConfig : nil
        }
        return configs.sorted { $0.path < $1.path }
    }

    static func resolveWindowsPath(fromUnixPath unixPath: String) -> String? {
        guard let driveRange = unixPath.range(of: "/drive_c/") else {
            return nil
        }

        let relativePath = unixPath[driveRange.upperBound...]
        let windowsRelative = relativePath.replacingOccurrences(of: "/", with: "\\")
        return "C:\\\(windowsRelative)"
    }

    private static func executableCandidates(
        in installDirectory: URL,
        gameName: String,
        fileManager: FileManager
    ) -> [GameExecutableCandidate] {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: installDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return []
        }

        let maxDepth = 7
        let maxEntries = 12_000
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
        let canonicalInstallPath = installDirectory.resolvingSymlinksInPath().path
        guard let enumerator = fileManager.enumerator(
            at: installDirectory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        let gameTokens = normalizedTokens(for: gameName)
        let installDirectoryName = installDirectory.lastPathComponent.lowercased()
        var scannedEntries = 0
        var candidates: [GameExecutableCandidate] = []

        for case let url as URL in enumerator {
            scannedEntries += 1
            if scannedEntries > maxEntries {
                break
            }

            let canonicalFilePath = url.resolvingSymlinksInPath().path
            guard canonicalFilePath.hasPrefix(canonicalInstallPath + "/") else {
                continue
            }
            let relativePath = String(canonicalFilePath.dropFirst(canonicalInstallPath.count + 1))
            let components = relativePath.split(separator: "/")
            if components.count > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            let lowerRelative = relativePath.lowercased()
            let shouldSkipDirectory = lowerRelative.contains("redist") ||
                lowerRelative.contains("_commonredist") ||
                lowerRelative.contains("directx") ||
                lowerRelative.contains("vcredist") ||
                lowerRelative.contains("support")

            if shouldSkipDirectory {
                enumerator.skipDescendants()
                continue
            }

            guard url.pathExtension.lowercased() == "exe" else {
                continue
            }

            let score = scoreExecutable(
                relativePath: relativePath,
                gameTokens: gameTokens,
                installDirectoryName: installDirectoryName
            )
            candidates.append(
                GameExecutableCandidate(
                    relativePath: relativePath,
                    absolutePath: canonicalFilePath,
                    score: score
                )
            )
        }

        return candidates.sorted {
            if $0.score == $1.score {
                if $0.relativePath.count == $1.relativePath.count {
                    return $0.relativePath.localizedCaseInsensitiveCompare($1.relativePath) == .orderedAscending
                }
                return $0.relativePath.count < $1.relativePath.count
            }
            return $0.score > $1.score
        }
    }

    private static func normalizedTokens(for gameName: String) -> [String] {
        gameName
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 }
    }

    private static func scoreExecutable(
        relativePath: String,
        gameTokens: [String],
        installDirectoryName: String
    ) -> Int {
        let lowerPath = relativePath.lowercased()
        let fileName = URL(fileURLWithPath: relativePath).lastPathComponent.lowercased()
        let baseName = URL(fileURLWithPath: relativePath).deletingPathExtension().lastPathComponent.lowercased()
        let depth = relativePath.split(separator: "/").count

        var score = 100
        score -= depth * 5

        if baseName == installDirectoryName {
            score += 80
        }
        if baseName == "game" {
            score += 20
        }
        if fileName.contains("shipping") {
            score += 18
        }
        if fileName.contains("launcher") {
            score -= 24
        }
        if fileName.contains("unins") || fileName.contains("uninstall") {
            score -= 90
        }
        if fileName.contains("crash") || fileName.contains("report") || fileName.contains("helper") {
            score -= 45
        }
        if lowerPath.contains("easyanticheat") || lowerPath.contains("anticheat") {
            score -= 50
        }
        if lowerPath.contains("redist") || lowerPath.contains("_commonredist") || lowerPath.contains("support") {
            score -= 70
        }

        for token in gameTokens where baseName.contains(token) {
            score += 15
        }

        return score
    }
}
