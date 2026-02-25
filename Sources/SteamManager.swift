import CoreGraphics
import Foundation

actor SteamManager {
    private struct GameManifestFingerprint: Equatable {
        let fileName: String
        let modificationTime: TimeInterval
        let fileSize: Int64
    }

    private struct GameLibraryFingerprint: Equatable {
        let steamRootPath: String
        let manifests: [GameManifestFingerprint]
    }

    private struct CachedGameLibraryState {
        let fingerprint: GameLibraryFingerprint
        let games: [InstalledGame]
    }

    private let fileManager = FileManager.default
    private let bundledScriptNames = [
        "common.sh",
        "install_prerequisites.sh",
        "install_runtime.sh",
        "setup_steam.sh",
        "launch_steam.sh",
        "stop_steam.sh",
        "wipe_steam_data.sh"
    ]
    private let appHome: URL
    private let prefixPath: URL
    private let logsPath: URL
    private let cachePath: URL
    private let settingsPath: URL
    private let gameProfilesPath: URL
    private let runtimeScriptsPath: URL
    private let crossOverRootPath = "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver"
    private let crossOverWrapperWinePath = "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine"
    private let crossOverUnixWinePath = "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/lib/wine/x86_64-unix/wine"
    private let compatibilityLayersRegistryPath = #"HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"#
    private lazy var cachedHardwareProfile: HardwareProfile = detectHardwareProfile()
    private var cachedGameLibraryState: CachedGameLibraryState?
    private var didDeployBundledScripts: Bool = false
    private static let diagnosticsTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private var crossOverBottleName: String {
        ProcessInfo.processInfo.environment["STEAVIUM_CROSSOVER_BOTTLE"] ?? "steavium-steam"
    }

    private var crossOverBottlePath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CrossOver/Bottles/\(crossOverBottleName)")
    }

    init(appHome: URL? = nil) {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let steaviumHome = applicationSupport.appendingPathComponent("Steavium", isDirectory: true)
        self.appHome = appHome ?? steaviumHome
        self.prefixPath = self.appHome.appendingPathComponent("prefixes/steam", isDirectory: true)
        self.logsPath = self.appHome.appendingPathComponent("logs", isDirectory: true)
        self.cachePath = self.appHome.appendingPathComponent("cache", isDirectory: true)
        self.settingsPath = self.appHome.appendingPathComponent("settings", isDirectory: true)
        self.gameProfilesPath = self.settingsPath.appendingPathComponent("game-profiles.json")
        self.runtimeScriptsPath = self.appHome.appendingPathComponent("runtime/scripts", isDirectory: true)
    }

    nonisolated var storeName: String { "Steam" }

    func snapshot() -> StoreEnvironment {
        let hardwareProfile = cachedHardwareProfile
        let steamExecutable = locateSteamExecutable()
        return StoreEnvironment(
            appHomePath: appHome.path,
            prefixPath: prefixPath.path,
            logsPath: logsPath.path,
            wine64Path: detectWine64(),
            storeAppInstalled: steamExecutable != nil,
            storeAppExecutablePath: steamExecutable,
            hardwareProfile: hardwareProfile
        )
    }

    func gameLibraryState(forceRefresh: Bool = false) -> GameLibraryState {
        let games = discoverInstalledGames(forceRefresh: forceRefresh)
        let profiles = (try? GameProfilePersistence.loadProfiles(from: gameProfilesPath)) ?? []
        return GameLibraryState(
            games: games,
            profiles: profiles.sorted(by: { $0.appID < $1.appID })
        )
    }

    func runtimePreflightReport() -> RuntimePreflightReport {
        let homebrewPath = detectHomebrewExecutable()
        let homebrewCheck: RuntimePreflightCheck = {
            if let homebrewPath {
                return RuntimePreflightCheck(
                    kind: .homebrew,
                    status: .ok,
                    detailEnglish: "Detected at \(homebrewPath).",
                    detailSpanish: "Detectado en \(homebrewPath)."
                )
            }
            return RuntimePreflightCheck(
                kind: .homebrew,
                status: .failed,
                detailEnglish: "Not detected. Runtime installation requires Homebrew.",
                detailSpanish: "No detectado. La instalacion del runtime requiere Homebrew."
            )
        }()

        let diskSpaceCheck: RuntimePreflightCheck = {
            guard let availableDiskGB = availableDiskSpaceGB(at: appHome) else {
                return RuntimePreflightCheck(
                    kind: .diskSpace,
                    status: .warning,
                    detailEnglish: "Could not determine available disk space.",
                    detailSpanish: "No se pudo determinar el espacio libre en disco."
                )
            }

            if availableDiskGB < 10 {
                return RuntimePreflightCheck(
                    kind: .diskSpace,
                    status: .failed,
                    detailEnglish: "Only \(availableDiskGB) GB available (recommended: at least 20 GB).",
                    detailSpanish: "Solo hay \(availableDiskGB) GB libres (recomendado: al menos 20 GB)."
                )
            }
            if availableDiskGB < 20 {
                return RuntimePreflightCheck(
                    kind: .diskSpace,
                    status: .warning,
                    detailEnglish: "\(availableDiskGB) GB available (recommended: at least 20 GB).",
                    detailSpanish: "\(availableDiskGB) GB libres (recomendado: al menos 20 GB)."
                )
            }
            return RuntimePreflightCheck(
                kind: .diskSpace,
                status: .ok,
                detailEnglish: "\(availableDiskGB) GB available.",
                detailSpanish: "\(availableDiskGB) GB libres."
            )
        }()

        let networkCheck: RuntimePreflightCheck = {
            do {
                _ = try ShellRunner.run(
                    executable: "/usr/bin/curl",
                    arguments: [
                        "-fIsS",
                        "--connect-timeout", "8",
                        "--max-time", "12",
                        "https://cdn.akamai.steamstatic.com"
                    ]
                )
                return RuntimePreflightCheck(
                    kind: .network,
                    status: .ok,
                    detailEnglish: "Steam CDN is reachable.",
                    detailSpanish: "El CDN de Steam es accesible."
                )
            } catch {
                return RuntimePreflightCheck(
                    kind: .network,
                    status: .failed,
                    detailEnglish: "Steam CDN is not reachable right now.",
                    detailSpanish: "El CDN de Steam no es accesible en este momento."
                )
            }
        }()

        let ffmpegCheck: RuntimePreflightCheck = {
            if let ffmpegPath = detectExecutable(named: "ffmpeg") {
                return RuntimePreflightCheck(
                    kind: .ffmpeg,
                    status: .ok,
                    detailEnglish: "Detected at \(ffmpegPath).",
                    detailSpanish: "Detectado en \(ffmpegPath)."
                )
            }
            return RuntimePreflightCheck(
                kind: .ffmpeg,
                status: .warning,
                detailEnglish: "Not detected. Multimedia fixes will be unavailable until installed.",
                detailSpanish: "No detectado. Las correcciones multimedia no estaran disponibles hasta instalarlo."
            )
        }()

        let runtimeCheck: RuntimePreflightCheck = {
            if let runtimePath = detectWine64() {
                return RuntimePreflightCheck(
                    kind: .runtime,
                    status: .ok,
                    detailEnglish: "Detected at \(runtimePath).",
                    detailSpanish: "Detectado en \(runtimePath)."
                )
            }
            return RuntimePreflightCheck(
                kind: .runtime,
                status: .warning,
                detailEnglish: "Not detected yet. Install Runtime will set it up.",
                detailSpanish: "Aun no detectado. Instalar Runtime lo configurara."
            )
        }()

        return RuntimePreflightReport(
            generatedAt: Date(),
            checks: [
                homebrewCheck,
                diskSpaceCheck,
                networkCheck,
                ffmpegCheck,
                runtimeCheck
            ]
        )
    }

    func installFFmpegDependency() async throws -> String {
        try prepareDirectories()
        guard let homebrewPath = detectHomebrewExecutable() else {
            throw StoreManagerError.homebrewNotFound
        }

        let result = try await ShellRunner.runAsync(
            executable: homebrewPath,
            arguments: ["install", "ffmpeg"],
            environment: ["STEAVIUM_HOME": appHome.path]
        )

        if result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "ffmpeg installed successfully."
        }
        return result.output
    }

    func createDiagnosticsArchive(
        selectedBackend: GraphicsBackend,
        inAppConsoleLog: String,
        preflightReport: RuntimePreflightReport
    ) async throws -> URL {
        try prepareDirectories()

        let timestamp = Self.diagnosticsTimestampFormatter.string(from: Date())
        let diagnosticsFolderURL = cachePath.appendingPathComponent("diagnostics-\(timestamp)", isDirectory: true)
        let diagnosticsArchiveURL = cachePath.appendingPathComponent("diagnostics-\(timestamp).zip")

        if fileManager.fileExists(atPath: diagnosticsFolderURL.path) {
            try fileManager.removeItem(at: diagnosticsFolderURL)
        }
        if fileManager.fileExists(atPath: diagnosticsArchiveURL.path) {
            try fileManager.removeItem(at: diagnosticsArchiveURL)
        }

        try fileManager.createDirectory(at: diagnosticsFolderURL, withIntermediateDirectories: true)

        let environment = snapshot()
        let libraryState = gameLibraryState(forceRefresh: false)
        let liveLogURL = logsPath.appendingPathComponent("steam-live.log")
        let reportURL = diagnosticsFolderURL.appendingPathComponent("report.txt")
        let inAppLogURL = diagnosticsFolderURL.appendingPathComponent("in-app-console.log")

        var reportLines: [String] = []
        reportLines.append("Steavium Diagnostics")
        reportLines.append("Generated at: \(ISO8601DateFormatter().string(from: Date()))")
        reportLines.append("")
        reportLines.append("[Environment]")
        reportLines.append("App home: \(environment.appHomePath)")
        reportLines.append("Prefix: \(environment.prefixPath)")
        reportLines.append("Logs: \(environment.logsPath)")
        reportLines.append("Steam installed: \(environment.storeAppInstalled)")
        reportLines.append("Steam executable: \(environment.storeAppExecutablePath ?? "-")")
        reportLines.append("Wine runtime: \(environment.wine64Path ?? "-")")
        reportLines.append("Selected backend: \(selectedBackend.rawValue)")
        reportLines.append("")
        reportLines.append("[Hardware]")
        reportLines.append("Chip: \(environment.hardwareProfile.chipModel)")
        reportLines.append("Chip family: \(environment.hardwareProfile.chipFamily.rawValue)")
        reportLines.append("Memory (GB): \(environment.hardwareProfile.memoryGB)")
        reportLines.append("CPU layout: \(environment.hardwareProfile.cpuCoreLayout.summary)")
        reportLines.append("Performance tier: \(environment.hardwareProfile.performanceTier.rawValue)")
        reportLines.append("Recommended backend: \(environment.hardwareProfile.recommendedBackend.rawValue)")
        reportLines.append("Recommended DXVK threads: \(environment.hardwareProfile.recommendedDXVKCompilerThreads)")
        reportLines.append("Recommended FPS cap: \(environment.hardwareProfile.recommendedFPSCap.map(String.init) ?? "-")")
        reportLines.append("Display: \(environment.hardwareProfile.displayResolutionIdentifier)")
        reportLines.append("")
        reportLines.append("[Library]")
        reportLines.append("Installed games: \(libraryState.games.count)")
        reportLines.append("Saved profiles: \(libraryState.profiles.count)")
        reportLines.append("")
        reportLines.append("[Preflight]")
        for check in preflightReport.checks {
            reportLines.append(
                "- \(check.kind.rawValue): \(check.status.rawValue) | \(check.detailEnglish)"
            )
        }

        let reportContent = reportLines.joined(separator: "\n")
        try reportContent.write(to: reportURL, atomically: true, encoding: .utf8)

        let consoleTail = tailLines(from: inAppConsoleLog, maxLines: 300)
        if !consoleTail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try consoleTail.write(to: inAppLogURL, atomically: true, encoding: .utf8)
        }

        if fileManager.fileExists(atPath: liveLogURL.path) {
            let destination = diagnosticsFolderURL.appendingPathComponent("steam-live.log")
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: liveLogURL, to: destination)
        }

        if fileManager.fileExists(atPath: gameProfilesPath.path) {
            let destination = diagnosticsFolderURL.appendingPathComponent("game-profiles.json")
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: gameProfilesPath, to: destination)
        }

        _ = try await ShellRunner.runAsync(
            executable: "/usr/bin/ditto",
            arguments: [
                "-c",
                "-k",
                "--sequesterRsrc",
                "--keepParent",
                diagnosticsFolderURL.path,
                diagnosticsArchiveURL.path
            ]
        )

        try? fileManager.removeItem(at: diagnosticsFolderURL)
        return diagnosticsArchiveURL
    }

    func saveGameCompatibilityProfile(_ profile: GameCompatibilityProfile) async throws -> String {
        try prepareDirectories()

        var normalized = profile
        normalized.refreshPresetFromFlags()

        var profilesByAppID = try loadProfilesDictionary()
        if normalized.hasOverrides {
            profilesByAppID[normalized.appID] = normalized
        } else {
            profilesByAppID.removeValue(forKey: normalized.appID)
        }
        try persistProfilesDictionary(profilesByAppID)

        let logs = try synchronizeGameProfiles(
            profilesByAppID: profilesByAppID,
            targetAppIDs: [normalized.appID]
        )
        let messagePrefix = normalized.hasOverrides
            ? "Profile saved for AppID \(normalized.appID)."
            : "Profile reset for AppID \(normalized.appID)."
        if logs.isEmpty {
            return messagePrefix
        }
        return ([messagePrefix] + logs).joined(separator: "\n")
    }

    func removeGameCompatibilityProfile(appID: Int) async throws -> String {
        try prepareDirectories()

        var profilesByAppID = try loadProfilesDictionary()
        let removed = profilesByAppID.removeValue(forKey: appID)
        try persistProfilesDictionary(profilesByAppID)

        let logs = try synchronizeGameProfiles(
            profilesByAppID: profilesByAppID,
            targetAppIDs: [appID],
            removedProfiles: removed.map { [appID: $0] } ?? [:]
        )
        let messagePrefix = "Profile removed for AppID \(appID)."
        if logs.isEmpty {
            return messagePrefix
        }
        return ([messagePrefix] + logs).joined(separator: "\n")
    }

    func installPrerequisites() async throws -> String {
        try prepareDirectories()
        let script = try materializeScript(named: "install_prerequisites.sh")

        let result = try await ShellRunner.runAsync(
            executable: "/bin/bash",
            arguments: [script.path],
            environment: ["STEAVIUM_HOME": appHome.path]
        )

        return result.output
    }

    func installRuntime() async throws -> String {
        try prepareDirectories()
        let script = try materializeScript(named: "install_runtime.sh")

        var env: [String: String] = ["STEAVIUM_HOME": appHome.path]
        if let rawMode = UserDefaults.standard.string(forKey: "steavium.wine_mode") {
            env["STEAVIUM_WINE_MODE"] = rawMode
        }

        let result = try await ShellRunner.runAsync(
            executable: "/bin/bash",
            arguments: [script.path],
            environment: env
        )

        return result.output
    }

    func setupStore(gameLibraryPath: String?) async throws -> String {
        try prepareDirectories()
        guard detectWine64() != nil else {
            throw StoreManagerError.wineRuntimeNotFound
        }

        let script = try materializeScript(named: "setup_steam.sh")
        let result = try await ShellRunner.runAsync(
            executable: "/bin/bash",
            arguments: [script.path],
            environment: scriptEnvironment(gameLibraryPath: gameLibraryPath)
        )
        invalidateGameLibraryCache()

        return result.output
    }

    func launchStoreDetached(
        graphicsBackend: GraphicsBackend,
        runningPolicy: StoreRunningPolicy,
        gameLibraryPath: String?
    ) async throws -> String {
        try prepareDirectories()
        guard detectWine64() != nil else {
            throw StoreManagerError.wineRuntimeNotFound
        }

        let profilesByAppID = try loadProfilesDictionary()
        let syncLogs = try synchronizeGameProfiles(
            profilesByAppID: profilesByAppID,
            targetAppIDs: Array(profilesByAppID.keys)
        )

        let script = try materializeScript(named: "launch_steam.sh")
        let hardwareProfile = cachedHardwareProfile
        var environment = scriptEnvironment(gameLibraryPath: gameLibraryPath)
        environment["STEAVIUM_GRAPHICS_BACKEND"] = graphicsBackend.rawValue
        environment["STEAVIUM_DEVICE_CHIP_MODEL"] = hardwareProfile.chipModel
        environment["STEAVIUM_DEVICE_CHIP_FAMILY"] = hardwareProfile.chipFamily.rawValue
        environment["STEAVIUM_DEVICE_RAM_GB"] = "\(hardwareProfile.memoryGB)"
        environment["STEAVIUM_DEVICE_PERFORMANCE_CORES"] = "\(hardwareProfile.cpuCoreLayout.performanceCores)"
        environment["STEAVIUM_DEVICE_EFFICIENCY_CORES"] = "\(hardwareProfile.cpuCoreLayout.efficiencyCores)"
        environment["STEAVIUM_DEVICE_LOGICAL_CORES"] = "\(hardwareProfile.cpuCoreLayout.logicalCores)"
        environment["STEAVIUM_PERFORMANCE_TIER"] = hardwareProfile.performanceTier.rawValue
        environment["STEAVIUM_RECOMMENDED_BACKEND"] = hardwareProfile.recommendedBackend.rawValue
        environment["STEAVIUM_RECOMMENDED_DXVK_COMPILER_THREADS"] = "\(hardwareProfile.recommendedDXVKCompilerThreads)"
        environment["STEAVIUM_RECOMMENDED_FPS_CAP"] = hardwareProfile.recommendedFPSCap.map(String.init) ?? ""
        environment["STEAVIUM_DISPLAY_REFRESH_RATE"] = "\(hardwareProfile.displayRefreshRate)"

        // Launch the script directly as a child process (fire-and-forget)
        // instead of using --detached + nohup. This keeps Wine in the
        // app's GUI session so its windows are visible — nohup'd workers
        // reparented to launchd can lose window-server access on macOS,
        // which causes Steam's window to never appear when the app is
        // installed from a DMG.
        let liveLogURL = logsPath.appendingPathComponent("steam-live.log")
        try ShellRunner.runFireAndForget(
            executable: "/bin/bash",
            arguments: [
                script.path,
                "--backend", graphicsBackend.rawValue,
                "--if-running", runningPolicy.rawValue
            ],
            environment: environment,
            outputFile: liveLogURL
        )

        let launchMessage = "Steam launched. Log: \(liveLogURL.path)"
        if syncLogs.isEmpty {
            return launchMessage
        }
        let syncOutput = syncLogs.joined(separator: "\n")
        return "[per-game]\n\(syncOutput)\n\n\(launchMessage)"
    }

    func stopStoreCompletely() async throws -> String {
        try prepareDirectories()

        let script = try materializeScript(named: "stop_steam.sh")
        let result = try await ShellRunner.runAsync(
            executable: "/bin/bash",
            arguments: [script.path],
            environment: scriptEnvironment(gameLibraryPath: nil)
        )

        return result.output
    }

    func isStoreRunning() async -> Bool {
        let steamPattern = #"^C:\\Program Files( \(x86\))?\\Steam\\[sS]team\.exe( |$)"#
        do {
            _ = try await ShellRunner.runAsync(
                executable: "/usr/bin/pgrep",
                arguments: ["-f", steamPattern]
            )
            return true
        } catch {
            return false
        }
    }

    func isStoreWindowVisible() async -> Bool {
        // Use AppleScript to check whether any visible window exists
        // in the Wine/CrossOver host process that contains "Steam".
        // This is far more accurate than pgrep, which detects the
        // process before the UI has loaded.
        let script = """
        tell application "System Events"
            set wList to every process whose visible is true
            repeat with p in wList
                try
                    set pName to name of p
                    if pName contains "steam" or pName contains "Steam" or pName contains "wine" or pName contains "Wine" or pName contains "CrossOver" then
                        if (count of windows of p) > 0 then
                            return true
                        end if
                    end if
                end try
            end repeat
        end tell
        return false
        """
        do {
            let result = try await ShellRunner.runAsync(
                executable: "/usr/bin/osascript",
                arguments: ["-e", script]
            )
            return result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        } catch {
            return false
        }
    }

    func wipeStoreData(clearAccountData: Bool, clearLibraryData: Bool) async throws -> String {
        try prepareDirectories()
        guard detectWine64() != nil else {
            throw StoreManagerError.wineRuntimeNotFound
        }
        guard clearAccountData || clearLibraryData else {
            throw StoreManagerError.dataWipeSelectionRequired
        }

        let script = try materializeScript(named: "wipe_steam_data.sh")
        var arguments = [script.path]
        if clearAccountData {
            arguments.append("--account")
        }
        if clearLibraryData {
            arguments.append("--library")
        }

        let result = try await ShellRunner.runAsync(
            executable: "/bin/bash",
            arguments: arguments,
            environment: scriptEnvironment(gameLibraryPath: nil)
        )
        invalidateGameLibraryCache()

        return result.output
    }

    private func scriptEnvironment(gameLibraryPath: String?) -> [String: String] {
        var environment: [String: String] = ["STEAVIUM_HOME": appHome.path]

        if let rawMode = UserDefaults.standard.string(forKey: "steavium.wine_mode") {
            environment["STEAVIUM_WINE_MODE"] = rawMode
        }

        // Ensure Homebrew and common binary paths are always reachable,
        // even when the app is launched from Finder (which provides a
        // minimal PATH like /usr/bin:/bin:/usr/sbin:/sbin).
        let currentPath = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        if !currentPath.contains("/opt/homebrew/bin") {
            environment["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:\(currentPath)"
        }

        if let gameLibraryPath {
            let trimmed = gameLibraryPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                environment["STEAVIUM_GAME_LIBRARY_PATH"] = trimmed
            }
        }
        return environment
    }

    private func detectHomebrewExecutable() -> String? {
        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ]

        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
            return candidate
        }

        if let path = (try? ShellRunner.run(executable: "/usr/bin/which", arguments: ["brew"]).output)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return path
        }

        return nil
    }

    private func detectExecutable(named executable: String) -> String? {
        if let path = (try? ShellRunner.run(executable: "/usr/bin/which", arguments: [executable]).output)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return path
        }

        let candidates = [
            "/opt/homebrew/bin/\(executable)",
            "/usr/local/bin/\(executable)",
            "/usr/bin/\(executable)"
        ]
        return candidates.first(where: { fileManager.isExecutableFile(atPath: $0) })
    }

    private func availableDiskSpaceGB(at path: URL) -> Int? {
        let resourceKeys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]

        guard let resourceValues = try? path.resourceValues(forKeys: resourceKeys) else {
            return nil
        }

        if let bytes = resourceValues.volumeAvailableCapacityForImportantUsage {
            return max(0, Int(bytes / 1_073_741_824))
        }
        if let bytes = resourceValues.volumeAvailableCapacity {
            return max(0, Int(bytes / 1_073_741_824))
        }

        return nil
    }

    private func prepareDirectories() throws {
        try fileManager.createDirectory(at: appHome, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: prefixPath, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logsPath, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cachePath, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: settingsPath, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: runtimeScriptsPath, withIntermediateDirectories: true)
    }

    private func materializeScript(named: String) throws -> URL {
        try deployBundledScripts()

        let destinationURL = runtimeScriptsPath.appendingPathComponent(named)
        if !fileManager.fileExists(atPath: destinationURL.path) {
            didDeployBundledScripts = false
            try deployBundledScripts()
        }
        guard fileManager.fileExists(atPath: destinationURL.path) else {
            throw StoreManagerError.missingScript(named)
        }

        return destinationURL
    }

    private func deployBundledScripts() throws {
        if didDeployBundledScripts {
            return
        }

        for scriptFile in bundledScriptNames {
            let scriptName = (scriptFile as NSString).deletingPathExtension
            let scriptExtension = (scriptFile as NSString).pathExtension

            guard let sourceURL = Bundle.module.url(
                forResource: scriptName,
                withExtension: scriptExtension.isEmpty ? nil : scriptExtension,
                subdirectory: "Resources/scripts"
            ) else {
                throw StoreManagerError.missingScript(scriptFile)
            }

            let destinationURL = runtimeScriptsPath.appendingPathComponent(scriptFile)
            if try shouldReplaceScript(at: destinationURL, with: sourceURL) {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }
            try fileManager.setAttributes(
                [.posixPermissions: NSNumber(value: 0o755)],
                ofItemAtPath: destinationURL.path
            )
        }

        didDeployBundledScripts = true
    }

    private func shouldReplaceScript(at destinationURL: URL, with sourceURL: URL) throws -> Bool {
        guard fileManager.fileExists(atPath: destinationURL.path) else {
            return true
        }

        let sourceData = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
        guard let destinationData = try? Data(contentsOf: destinationURL, options: [.mappedIfSafe]) else {
            return true
        }

        return sourceData != destinationData
    }

    private func detectWine64() -> String? {
        let mode = UserDefaults.standard.string(forKey: "steavium.wine_mode") ?? "auto"

        let crossoverCandidates = [
            "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine",
            "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/lib/wine/x86_64-unix/wine"
        ]
        let wineCandidates = [
            "/Applications/Wine Crossover.app/Contents/Resources/wine/bin/wine64",
            "/Applications/Whisky.app/Contents/Resources/wine/bin/wine64",
            "/opt/homebrew/bin/wine64",
            "/opt/homebrew/bin/wine",
            "/usr/local/bin/wine64",
            "/usr/local/bin/wine"
        ]

        let bundledCandidates: [String]
        switch mode {
        case "crossover":
            bundledCandidates = crossoverCandidates
        case "wine":
            bundledCandidates = wineCandidates
        default:
            bundledCandidates = crossoverCandidates + wineCandidates
        }

        for candidate in bundledCandidates where fileManager.isExecutableFile(atPath: candidate) {
            return candidate
        }

        if mode != "crossover" {
            for executable in ["wine", "wine64"] {
                if let path = (try? ShellRunner.run(executable: "/usr/bin/which", arguments: [executable]).output)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        }

        return nil
    }

    private func locateSteamExecutable() -> String? {
        let crossOverBottleName = ProcessInfo.processInfo.environment["STEAVIUM_CROSSOVER_BOTTLE"] ?? "steavium-steam"
        let crossOverBottlePath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CrossOver/Bottles/\(crossOverBottleName)")

        let candidates: [(exe: String, manifest: String)] = [
            (
                crossOverBottlePath.appendingPathComponent("drive_c/Program Files (x86)/Steam/steam.exe").path,
                crossOverBottlePath.appendingPathComponent("drive_c/Program Files (x86)/Steam/package/steam_client_win64.installed").path
            ),
            (
                crossOverBottlePath.appendingPathComponent("drive_c/Program Files/Steam/Steam.exe").path,
                crossOverBottlePath.appendingPathComponent("drive_c/Program Files/Steam/package/steam_client_win64.installed").path
            ),
            (
                prefixPath.appendingPathComponent("drive_c/Program Files (x86)/Steam/steam.exe").path,
                prefixPath.appendingPathComponent("drive_c/Program Files (x86)/Steam/package/steam_client_win64.installed").path
            ),
            (
                prefixPath.appendingPathComponent("drive_c/Program Files/Steam/steam.exe").path,
                prefixPath.appendingPathComponent("drive_c/Program Files/Steam/package/steam_client_win64.installed").path
            )
        ]

        for candidate in candidates
            where fileManager.fileExists(atPath: candidate.exe) && fileManager.fileExists(atPath: candidate.manifest) {
            return candidate.exe
        }

        for candidate in candidates where fileManager.fileExists(atPath: candidate.exe) {
            return candidate.exe
        }

        return nil
    }

    private func discoverInstalledGames(forceRefresh: Bool = false) -> [InstalledGame] {
        guard let steamExecutablePath = locateSteamExecutable() else {
            invalidateGameLibraryCache()
            return []
        }
        let steamRoot = GameLibraryScanner.steamRoot(steamExecutablePath: steamExecutablePath)

        let fingerprint = gameLibraryFingerprint(steamRoot: steamRoot)
        if !forceRefresh,
           let cachedGameLibraryState,
           cachedGameLibraryState.fingerprint == fingerprint {
            return cachedGameLibraryState.games
        }

        let games = GameLibraryScanner.discoverInstalledGames(steamRoot: steamRoot, fileManager: fileManager)
        cachedGameLibraryState = CachedGameLibraryState(
            fingerprint: fingerprint,
            games: games
        )
        return games
    }

    private func steamRootURL() -> URL? {
        guard let steamExecutablePath = locateSteamExecutable() else {
            return nil
        }
        return GameLibraryScanner.steamRoot(steamExecutablePath: steamExecutablePath)
    }

    private func invalidateGameLibraryCache() {
        cachedGameLibraryState = nil
    }

    private func gameLibraryFingerprint(steamRoot: URL) -> GameLibraryFingerprint {
        let steamAppsPath = steamRoot.appendingPathComponent("steamapps", isDirectory: true)
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
        guard let manifestURLs = try? fileManager.contentsOfDirectory(
            at: steamAppsPath,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return GameLibraryFingerprint(
                steamRootPath: steamRoot.path,
                manifests: []
            )
        }

        let manifests = manifestURLs
            .filter { $0.lastPathComponent.hasPrefix("appmanifest_") && $0.pathExtension.lowercased() == "acf" }
            .compactMap { manifestURL -> GameManifestFingerprint? in
                guard let resourceValues = try? manifestURL.resourceValues(forKeys: keys),
                      resourceValues.isRegularFile == true else {
                    return nil
                }

                let modificationTime = resourceValues.contentModificationDate?.timeIntervalSince1970 ?? 0
                let fileSize = Int64(resourceValues.fileSize ?? 0)
                return GameManifestFingerprint(
                    fileName: manifestURL.lastPathComponent,
                    modificationTime: modificationTime,
                    fileSize: fileSize
                )
            }
            .sorted { lhs, rhs in
                lhs.fileName < rhs.fileName
            }

        return GameLibraryFingerprint(
            steamRootPath: steamRoot.path,
            manifests: manifests
        )
    }

    private func loadProfilesDictionary() throws -> [Int: GameCompatibilityProfile] {
        let profiles = try GameProfilePersistence.loadProfiles(from: gameProfilesPath, fileManager: fileManager)
        return Dictionary(uniqueKeysWithValues: profiles.map { ($0.appID, $0) })
    }

    private func persistProfilesDictionary(_ profilesByAppID: [Int: GameCompatibilityProfile]) throws {
        try GameProfilePersistence.saveProfiles(
            Array(profilesByAppID.values),
            to: gameProfilesPath,
            fileManager: fileManager
        )
    }

    private func synchronizeGameProfiles(
        profilesByAppID: [Int: GameCompatibilityProfile],
        targetAppIDs: [Int],
        removedProfiles: [Int: GameCompatibilityProfile] = [:]
    ) throws -> [String] {
        guard !targetAppIDs.isEmpty else {
            return []
        }

        guard let steamRoot = steamRootURL() else {
            return ["Steam not found: profile saved and will be applied when Steam is available."]
        }

        let games = discoverInstalledGames(forceRefresh: false)
        let gamesByAppID = Dictionary(uniqueKeysWithValues: games.map { ($0.appID, $0) })
        let localConfigPaths = GameLibraryScanner.locateLocalConfigFiles(steamRoot: steamRoot, fileManager: fileManager)

        var output: [String] = []
        var compatibilityLayerValues: [String: String] = [:]
        do {
            compatibilityLayerValues = try compatibilityLayerRegistryValues()
        } catch {
            output.append("[CompatLayer] Failed to read current registry state: \(error.localizedDescription)")
        }
        if localConfigPaths.isEmpty {
            output.append("localconfig.vdf not found (Steam has not been signed into yet).")
        }

        for appID in targetAppIDs.sorted() {
            let activeProfile = profilesByAppID[appID]
            let previousProfile = removedProfiles[appID]
            let profileForExecutable = activeProfile ?? previousProfile
            let game = gamesByAppID[appID]
            let forceWindowed = activeProfile?.forceWindowed ?? false

            for localConfig in localConfigPaths {
                do {
                    let changed = try synchronizeLaunchOptions(
                        appID: appID,
                        forceWindowed: forceWindowed,
                        localConfigURL: localConfig
                    )
                    if changed {
                        output.append("[LaunchOptions] AppID \(appID) updated in \(localConfig.path).")
                    }
                } catch {
                    output.append("[LaunchOptions] AppID \(appID) failed in \(localConfig.path): \(error.localizedDescription)")
                }
            }

            guard let profileForExecutable else {
                continue
            }

            do {
                if let compatLog = try synchronizeCompatibilityLayer(
                    appID: appID,
                    game: game,
                    profileForExecutable: profileForExecutable,
                    activeProfile: activeProfile,
                    compatibilityLayerValues: &compatibilityLayerValues
                ) {
                    output.append(compatLog)
                }
            } catch {
                output.append("[CompatLayer] AppID \(appID) error: \(error.localizedDescription)")
            }
        }

        return output
    }

    private func synchronizeLaunchOptions(
        appID: Int,
        forceWindowed: Bool,
        localConfigURL: URL
    ) throws -> Bool {
        let content = try String(contentsOf: localConfigURL, encoding: .utf8)
        var document = try ValveKeyValueDocument.parse(content)

        let path = [
            "UserLocalConfigStore", "Software", "Valve", "Steam", "apps", "\(appID)", "LaunchOptions"
        ]
        let existingLaunchOptions = document.string(at: path) ?? ""
        let managedSegment = GameLaunchOptionsComposer.managedSegment(forceWindowed: forceWindowed)
        let mergedLaunchOptions = GameLaunchOptionsComposer.merge(
            existing: existingLaunchOptions,
            managedSegment: managedSegment
        )

        if mergedLaunchOptions.isEmpty {
            document.removeValue(at: path)
        } else {
            document.setString(mergedLaunchOptions, at: path)
        }

        let updatedContent = document.serialized()
        guard updatedContent != content else {
            return false
        }

        do {
            try updatedContent.write(to: localConfigURL, atomically: true, encoding: .utf8)
        } catch {
            throw StoreManagerError.gameProfileLocalConfigWriteFailed(path: localConfigURL.path)
        }
        return true
    }

    private func synchronizeCompatibilityLayer(
        appID: Int,
        game: InstalledGame?,
        profileForExecutable: GameCompatibilityProfile,
        activeProfile: GameCompatibilityProfile?,
        compatibilityLayerValues: inout [String: String]
    ) throws -> String? {
        let selectedRelativeExecutable = profileForExecutable.executableRelativePath
        guard let executablePath = resolveExecutablePath(
            game: game,
            selectedRelativeExecutable: selectedRelativeExecutable
        ) else {
            if activeProfile?.compatibilityLayerFlags.isEmpty == false || activeProfile == nil {
                return "[CompatLayer] AppID \(appID): could not resolve executable to apply flags."
            }
            return nil
        }

        guard let windowsExecutablePath = GameLibraryScanner.resolveWindowsPath(fromUnixPath: executablePath) else {
            return "[CompatLayer] AppID \(appID): path outside drive_c, not applicable."
        }

        let escapedWindowsPath = escapedRegistryValueName(for: windowsExecutablePath)
        let currentRawFlags = compatibilityLayerValues[windowsExecutablePath] ?? compatibilityLayerValues[escapedWindowsPath]
        let currentFlags = normalizedFlagSet(from: currentRawFlags ?? "")
        let newFlags = activeProfile?.compatibilityLayerFlags ?? []
        let expectedFlags = Set(newFlags)
        if newFlags.isEmpty {
            guard !currentFlags.isEmpty else {
                return nil
            }
            try removeCompatibilityLayerFlags(
                windowsExecutablePath: windowsExecutablePath,
                compatibilityLayerValues: &compatibilityLayerValues
            )
            return "[CompatLayer] AppID \(appID): compatibility flags removed."
        }

        guard currentFlags != expectedFlags else {
            return nil
        }

        let value = newFlags.joined(separator: " ")
        try setCompatibilityLayerFlags(
            windowsExecutablePath: windowsExecutablePath,
            flagsValue: value,
            compatibilityLayerValues: &compatibilityLayerValues
        )
        return "[CompatLayer] AppID \(appID): flags applied (\(value))."
    }

    private func resolveExecutablePath(
        game: InstalledGame?,
        selectedRelativeExecutable: String?
    ) -> String? {
        guard let game else {
            return nil
        }

        let selected = selectedRelativeExecutable?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !selected.isEmpty {
            let selectedPath = URL(fileURLWithPath: game.installDirectoryPath)
                .appendingPathComponent(selected)
                .path
            if fileManager.fileExists(atPath: selectedPath) {
                return selectedPath
            }
        }

        if let defaultRelative = game.defaultExecutableRelativePath {
            let defaultPath = URL(fileURLWithPath: game.installDirectoryPath)
                .appendingPathComponent(defaultRelative)
                .path
            if fileManager.fileExists(atPath: defaultPath) {
                return defaultPath
            }
        }

        return nil
    }

    private func setCompatibilityLayerFlags(
        windowsExecutablePath: String,
        flagsValue: String,
        compatibilityLayerValues: inout [String: String]
    ) throws {
        let escapedWindowsPath = escapedRegistryValueName(for: windowsExecutablePath)
        if escapedWindowsPath != windowsExecutablePath {
            try removeCompatibilityLayerValue(windowsExecutablePath: escapedWindowsPath)
        }

        _ = try runWineRegistryCommand(
            arguments: [
                "reg",
                "add",
                compatibilityLayersRegistryPath,
                "/v",
                windowsExecutablePath,
                "/t",
                "REG_SZ",
                "/d",
                flagsValue,
                "/f"
            ]
        )
        compatibilityLayerValues[windowsExecutablePath] = flagsValue
        compatibilityLayerValues.removeValue(forKey: escapedWindowsPath)
    }

    private func removeCompatibilityLayerFlags(
        windowsExecutablePath: String,
        compatibilityLayerValues: inout [String: String]
    ) throws {
        try removeCompatibilityLayerValue(windowsExecutablePath: windowsExecutablePath)
        let escapedWindowsPath = escapedRegistryValueName(for: windowsExecutablePath)
        if escapedWindowsPath != windowsExecutablePath {
            try removeCompatibilityLayerValue(windowsExecutablePath: escapedWindowsPath)
        }
        compatibilityLayerValues.removeValue(forKey: windowsExecutablePath)
        compatibilityLayerValues.removeValue(forKey: escapedWindowsPath)
    }

    private func removeCompatibilityLayerValue(windowsExecutablePath: String) throws {
        do {
            _ = try runWineRegistryCommand(
                arguments: [
                    "reg",
                    "delete",
                    compatibilityLayersRegistryPath,
                    "/v",
                    windowsExecutablePath,
                    "/f"
                ]
            )
        } catch let ShellError.exitedNonZero(_, _, output) where isMissingRegistryObjectOutput(output) {
            // Missing values are acceptable when resetting a profile.
        }
    }

    private func compatibilityLayerRegistryValues() throws -> [String: String] {
        let queryResult: ShellResult
        do {
            queryResult = try runWineRegistryCommand(
                arguments: [
                    "reg",
                    "query",
                    compatibilityLayersRegistryPath
                ]
            )
        } catch let ShellError.exitedNonZero(_, _, output) where isMissingRegistryObjectOutput(output) {
            return [:]
        }

        var values: [String: String] = [:]
        for line in queryResult.output.split(whereSeparator: \.isNewline) {
            let trimmedLine = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty, !trimmedLine.hasPrefix("HKEY_") else {
                continue
            }
            guard let separatorRange = trimmedLine.range(of: "REG_SZ") else {
                continue
            }

            let valueName = trimmedLine[..<separatorRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let valueData = trimmedLine[separatorRange.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !valueName.isEmpty {
                values[valueName] = valueData
            }
        }
        return values
    }

    private func normalizedFlagSet(from flagsValue: String) -> Set<String> {
        Set(
            flagsValue
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
        )
    }

    private func escapedRegistryValueName(for windowsExecutablePath: String) -> String {
        windowsExecutablePath.replacingOccurrences(of: "\\", with: "\\\\")
    }

    private func isMissingRegistryObjectOutput(_ output: String) -> Bool {
        let normalizedOutput = output.lowercased()
        return normalizedOutput.contains("unable to find") ||
            normalizedOutput.contains("cannot find") ||
            normalizedOutput.contains("could not find") ||
            normalizedOutput.contains("no se pudo encontrar")
    }

    private func runWineRegistryCommand(arguments: [String]) throws -> ShellResult {
        if fileManager.isExecutableFile(atPath: crossOverUnixWinePath),
           fileManager.fileExists(atPath: crossOverBottlePath.path) {
            var environment = scriptEnvironment(gameLibraryPath: nil)
            environment["CX_ROOT"] = crossOverRootPath
            environment["WINEPREFIX"] = crossOverBottlePath.path
            environment["WINEARCH"] = "win64"
            environment["WINEESYNC"] = "1"
            environment["WINEFSYNC"] = "1"
            environment["WINEMSYNC"] = "1"
            return try ShellRunner.run(
                executable: crossOverUnixWinePath,
                arguments: arguments,
                environment: environment
            )
        }

        if fileManager.isExecutableFile(atPath: crossOverWrapperWinePath),
           fileManager.fileExists(atPath: crossOverBottlePath.path) {
            var environment = scriptEnvironment(gameLibraryPath: nil)
            environment["WINEESYNC"] = "1"
            environment["WINEFSYNC"] = "1"
            environment["WINEMSYNC"] = "1"
            return try ShellRunner.run(
                executable: crossOverWrapperWinePath,
                arguments: ["--no-gui", "--bottle", crossOverBottleName] + arguments,
                environment: environment
            )
        }

        guard let wineExecutable = detectWine64() else {
            throw StoreManagerError.wineRuntimeNotFound
        }

        var environment = scriptEnvironment(gameLibraryPath: nil)
        environment["WINEPREFIX"] = prefixPath.path
        environment["WINEARCH"] = "win64"
        environment["WINEESYNC"] = "1"
        environment["WINEFSYNC"] = "1"
        environment["WINEMSYNC"] = "1"
        return try ShellRunner.run(
            executable: wineExecutable,
            arguments: arguments,
            environment: environment
        )
    }

    private func detectHardwareProfile() -> HardwareProfile {
        let chipModel = detectChipModel()
        let chipFamily = classifyChipFamily(from: chipModel)
        let memoryGB = max(1, Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824))
        let cpuCoreLayout = detectCPUCoreLayout()
        let displayResolutionIdentifier = detectDisplayResolutionIdentifier()
        let performanceTier = classifyPerformanceTier(chipFamily: chipFamily, memoryGB: memoryGB)
        let recommendedBackend = HardwareTuningAdvisor.recommendedBackend(
            chipFamily: chipFamily,
            performanceTier: performanceTier,
            memoryGB: memoryGB
        )
        let displayRefreshRate = detectDisplayRefreshRate()
        let recommendedFPSCap = HardwareTuningAdvisor.recommendedFPSCap(
            performanceTier: performanceTier,
            displayRefreshRate: displayRefreshRate
        )
        let recommendedDXVKCompilerThreads = HardwareTuningAdvisor.recommendedDXVKCompilerThreads(
            performanceTier: performanceTier,
            memoryGB: memoryGB,
            coreLayout: cpuCoreLayout
        )

        return HardwareProfile(
            chipModel: chipModel,
            chipFamily: chipFamily,
            memoryGB: memoryGB,
            cpuCoreLayout: cpuCoreLayout,
            performanceTier: performanceTier,
            recommendedBackend: recommendedBackend,
            recommendedDXVKCompilerThreads: recommendedDXVKCompilerThreads,
            recommendedFPSCap: recommendedFPSCap,
            displayRefreshRate: displayRefreshRate,
            displayResolutionIdentifier: displayResolutionIdentifier
        )
    }

    private func detectDisplayRefreshRate() -> Int {
        let mainDisplayID = CGMainDisplayID()
        guard let displayMode = CGDisplayCopyDisplayMode(mainDisplayID) else {
            return 60
        }
        let rate = Int(displayMode.refreshRate)
        // Some displays report 0 Hz (e.g. virtual displays); default to 60.
        return rate > 0 ? rate : 60
    }

    private func detectDisplayResolutionIdentifier() -> String {
        let mainDisplayID = CGMainDisplayID()
        guard let displayMode = CGDisplayCopyDisplayMode(mainDisplayID) else {
            return "Not detected"
        }

        let currentWidth = displayMode.width
        let currentHeight = displayMode.height
        let nativeWidth = displayMode.pixelWidth
        let nativeHeight = displayMode.pixelHeight
        let currentID = "\(currentWidth)x\(currentHeight)"
        let nativeID = "\(nativeWidth)x\(nativeHeight)"

        if currentWidth == nativeWidth && currentHeight == nativeHeight {
            return currentID
        }

        let safeCurrentWidth = max(currentWidth, 1)
        let safeCurrentHeight = max(currentHeight, 1)
        let scaleX = Double(nativeWidth) / Double(safeCurrentWidth)
        let scaleY = Double(nativeHeight) / Double(safeCurrentHeight)

        let scaleText: String
        if abs(scaleX - scaleY) < 0.05 {
            scaleText = String(format: "%.2fx", scaleX)
        } else {
            scaleText = String(format: "%.2fx/%.2fx", scaleX, scaleY)
        }
        return "\(currentID) (native \(nativeID), scale \(scaleText))"
    }

    private func detectChipModel() -> String {
        if let brand = runAndCapture(executable: "/usr/sbin/sysctl", arguments: ["-n", "machdep.cpu.brand_string"]),
           !brand.isEmpty {
            return brand
        }

        if let model = runAndCapture(executable: "/usr/sbin/sysctl", arguments: ["-n", "hw.model"]),
           !model.isEmpty {
            return model
        }

        return "Unknown"
    }

    private func detectCPUCoreLayout() -> CPUCoreLayout {
        let performanceCores = detectIntegerSysctl("hw.perflevel0.physicalcpu")
            ?? detectIntegerSysctl("hw.physicalcpu")
            ?? detectIntegerSysctl("hw.ncpu")
            ?? 0
        let efficiencyCores = detectIntegerSysctl("hw.perflevel1.physicalcpu") ?? 0
        let logicalCores = detectIntegerSysctl("hw.logicalcpu")
            ?? detectIntegerSysctl("hw.ncpu")
            ?? max(performanceCores + efficiencyCores, 0)

        return CPUCoreLayout(
            performanceCores: max(0, performanceCores),
            efficiencyCores: max(0, efficiencyCores),
            logicalCores: max(0, logicalCores)
        )
    }

    private func detectIntegerSysctl(_ key: String) -> Int? {
        guard let value = runAndCapture(executable: "/usr/sbin/sysctl", arguments: ["-n", key]),
              let integerValue = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return integerValue
    }

    private func runAndCapture(executable: String, arguments: [String]) -> String? {
        guard let output = try? ShellRunner.run(executable: executable, arguments: arguments).output else {
            return nil
        }

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func tailLines(from text: String, maxLines: Int) -> String {
        guard maxLines > 0 else { return "" }
        let lines = text.split(whereSeparator: \.isNewline)
        guard lines.count > maxLines else {
            return text
        }
        let tail = lines.suffix(maxLines).map(String.init)
        return tail.joined(separator: "\n")
    }

    private func classifyChipFamily(from chipModel: String) -> AppleChipFamily {
        let normalized = chipModel.lowercased()
        if normalized.contains("m5") {
            return .m5
        }
        if normalized.contains("m4") {
            return .m4
        }
        if normalized.contains("m3") {
            return .m3
        }
        if normalized.contains("m2") {
            return .m2
        }
        if normalized.contains("m1") {
            return .m1
        }
        if normalized.contains("intel") {
            return .intel
        }
        if normalized.contains("apple") {
            return .appleSiliconOther
        }
        return .unknown
    }

    private func classifyPerformanceTier(chipFamily: AppleChipFamily, memoryGB: Int) -> PerformanceTier {
        switch chipFamily {
        case .m5:
            // M5: ~7.4 TFLOPS GPU, 153 GB/s bandwidth, 3rd-gen ray tracing.
            // 45% graphics uplift over M4 justifies aggressive tiers.
            if memoryGB >= 16 {
                return .extreme
            }
            if memoryGB >= 8 {
                return .performance
            }
            return .balanced
        case .m4:
            // M4: ~5.3 TFLOPS GPU, 120 GB/s bandwidth, improved ray tracing.
            if memoryGB >= 24 {
                return .extreme
            }
            if memoryGB >= 16 {
                return .performance
            }
            return .balanced
        case .m3:
            // M3: ~4.1 TFLOPS GPU, 100 GB/s, HW ray tracing + dynamic caching.
            if memoryGB >= 32 {
                return .extreme
            }
            if memoryGB >= 16 {
                return .performance
            }
            if memoryGB >= 8 {
                return .balanced
            }
            return .economy
        case .m2:
            // M2: ~3.6 TFLOPS GPU, 100 GB/s bandwidth — ~35% more GPU
            // power than M1. Previous thresholds undervalued the M2.
            if memoryGB >= 16 {
                return .performance
            }
            if memoryGB >= 8 {
                return .balanced
            }
            return .economy
        case .m1:
            // M1: ~2.6 TFLOPS GPU, 68 GB/s bandwidth — baseline Apple Silicon.
            if memoryGB >= 32 {
                return .performance
            }
            if memoryGB >= 16 {
                return .balanced
            }
            return .economy
        case .appleSiliconOther:
            if memoryGB >= 16 {
                return .performance
            }
            if memoryGB >= 8 {
                return .balanced
            }
            return .economy
        case .intel, .unknown:
            if memoryGB >= 32 {
                return .performance
            }
            if memoryGB >= 16 {
                return .balanced
            }
            return .economy
        }
    }
}
