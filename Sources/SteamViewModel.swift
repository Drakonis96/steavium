import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class SteamViewModel: ObservableObject {
    @Published var environment: SteamEnvironment = .empty
    @Published var logs: String = ""
    @Published var statusText: String = "Ready."
    @Published var isBusy: Bool = false
    @Published var showingSteamRunningDialog: Bool = false
    @Published var language: AppLanguage = .english {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageDefaultsKey)
        }
    }
    @Published var gameLibraryPath: String = "" {
        didSet {
            let trimmed = gameLibraryPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: Self.gameLibraryDefaultsKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: Self.gameLibraryDefaultsKey)
            }
        }
    }
    @Published var connectedGamepads: [GamepadDeviceInfo] = []
    @Published var launchPhase: LaunchPhase?
    @Published var graphicsBackend: GraphicsBackend = .auto {
        didSet {
            UserDefaults.standard.set(graphicsBackend.rawValue, forKey: Self.graphicsBackendDefaultsKey)
        }
    }
    @Published var installedGames: [InstalledGame] = []
    @Published var selectedGameID: Int? {
        didSet {
            loadEditorForSelectedGame()
        }
    }
    @Published var profileEditor: GameProfileEditorState = .empty
    @Published var preflightReport: RuntimePreflightReport = .empty

    private let manager: any SteamManaging
    private static let graphicsBackendDefaultsKey = "steavium.graphics_backend"
    private static let gameLibraryDefaultsKey = "steavium.game_library_path"
    private static let languageDefaultsKey = "steavium.language"
    private static let logTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    private var pendingLaunchBackend: GraphicsBackend?
    private var gamepadMonitor: GamepadMonitor?
    private var profilesByAppID: [Int: GameCompatibilityProfile] = [:]

    init(manager: any SteamManaging = SteamManager()) {
        self.manager = manager
        if let rawLanguage = UserDefaults.standard.string(forKey: Self.languageDefaultsKey),
           let storedLanguage = AppLanguage(rawValue: rawLanguage) {
            language = storedLanguage
        }

        if let rawBackend = UserDefaults.standard.string(forKey: Self.graphicsBackendDefaultsKey),
           let backend = GraphicsBackend(rawValue: rawBackend) {
            graphicsBackend = backend
        }
        if let storedLibraryPath = UserDefaults.standard.string(forKey: Self.gameLibraryDefaultsKey) {
            gameLibraryPath = storedLibraryPath
        }
        statusText = L.ready.resolve(in: language)

        gamepadMonitor = GamepadMonitor { [weak self] devices in
            self?.connectedGamepads = devices
        }
        gamepadMonitor?.start()

        Task {
            await refreshEnvironment()
            await refreshPreflightReport()
            await refreshGameLibraryState(forceRefresh: true)
        }
    }

    func refreshEnvironment() async {
        environment = await manager.snapshot()
    }

    func refreshInstalledGames(forceRefresh: Bool = true) {
        Task {
            await refreshGameLibraryState(forceRefresh: forceRefresh)
        }
    }

    func refreshPreflight() {
        Task {
            await refreshPreflightReport()
            statusText = L.preflightRefreshed.resolve(in: language)
        }
    }

    func installRuntime() {
        runAction(
            title: L.runtimeInstallation.resolve(in: language),
            refreshPreflightAfterCompletion: true
        ) { [weak self] manager in
            let report = await manager.runtimePreflightReport()
            await MainActor.run {
                self?.preflightReport = report
            }

            guard !report.hasBlockingFailures else {
                throw SteamManagerError.preflightBlocking(report.blockingFailureKinds)
            }

            return try await manager.installRuntime()
        }
    }

    func setupSteam() {
        let gameLibraryPath = selectedGameLibraryPath
        runAction(title: L.steamSetup.resolve(in: language)) { manager in
            try await manager.setupSteam(gameLibraryPath: gameLibraryPath)
        }
    }

    func launchSteam() {
        guard !isBusy else { return }

        let backend = graphicsBackend
        Task {
            let running = await manager.isSteamRunning()
            if running {
                pendingLaunchBackend = backend
                showingSteamRunningDialog = true
                return
            }

            launchSteamNow(runningPolicy: .reuseExisting, backend: backend)
        }
    }

    func launchSteamReusingSession() {
        showingSteamRunningDialog = false
        let backend = pendingLaunchBackend ?? graphicsBackend
        pendingLaunchBackend = nil
        launchSteamNow(runningPolicy: .reuseExisting, backend: backend)
    }

    func launchSteamRestarting() {
        showingSteamRunningDialog = false
        let backend = pendingLaunchBackend ?? graphicsBackend
        pendingLaunchBackend = nil
        launchSteamNow(runningPolicy: .restart, backend: backend)
    }

    func cancelSteamLaunchDecision() {
        showingSteamRunningDialog = false
        pendingLaunchBackend = nil
        statusText = L.steamLaunchCanceled.resolve(in: language)
    }

    func stopSteamCompletely() {
        runAction(title: L.completeSteamShutdown.resolve(in: language)) { manager in
            try await manager.stopSteamCompletely()
        }
    }

    func wipeSteamData(clearAccountData: Bool, clearLibraryData: Bool) {
        runAction(title: L.dataWipe.resolve(in: language)) { manager in
            try await manager.wipeSteamData(
                clearAccountData: clearAccountData,
                clearLibraryData: clearLibraryData
            )
        }
    }

    func saveSelectedGameProfile() {
        guard var profile = profileEditor.makeProfile() else { return }
        profile.refreshPresetFromFlags()
        runAction(title: L.perGameProfileSave.resolve(in: language)) { manager in
            try await manager.saveGameCompatibilityProfile(profile)
        }
    }

    func resetSelectedGameProfile() {
        guard let selectedGameID else { return }
        runAction(title: L.perGameProfileReset.resolve(in: language)) { manager in
            try await manager.removeGameCompatibilityProfile(appID: selectedGameID)
        }
    }

    func applySelectedPreset(_ preset: GameCompatibilityPreset) {
        guard var profile = profileEditor.makeProfile() else { return }
        profile.applyPreset(preset)
        applyProfileToEditor(profile)
    }

    func setSelectedExecutablePath(_ relativePath: String) {
        mutateProfileEditor { editor in
            editor.selectedExecutableRelativePath = relativePath
        }
    }

    func setCompatibilityMode(_ mode: GameCompatibilityMode) {
        mutateProfileEditor { editor in
            editor.compatibilityMode = mode
        }
        refreshEditorPresetFromFlags()
    }

    func setForceWindowed(_ enabled: Bool) {
        mutateProfileEditor { editor in
            editor.forceWindowed = enabled
        }
        refreshEditorPresetFromFlags()
    }

    func setForce640x480(_ enabled: Bool) {
        mutateProfileEditor { editor in
            editor.force640x480 = enabled
        }
        refreshEditorPresetFromFlags()
    }

    func setReducedColorMode(_ mode: GameReducedColorMode) {
        mutateProfileEditor { editor in
            editor.reducedColorMode = mode
        }
        refreshEditorPresetFromFlags()
    }

    func setHighDPIOverrideMode(_ mode: GameHighDPIOverrideMode) {
        mutateProfileEditor { editor in
            editor.highDPIOverrideMode = mode
        }
        refreshEditorPresetFromFlags()
    }

    func setDisableFullscreenOptimizations(_ enabled: Bool) {
        mutateProfileEditor { editor in
            editor.disableFullscreenOptimizations = enabled
        }
        refreshEditorPresetFromFlags()
    }

    func setRunAsAdmin(_ enabled: Bool) {
        mutateProfileEditor { editor in
            editor.runAsAdmin = enabled
        }
        refreshEditorPresetFromFlags()
    }

    func clearLogs() {
        logs = ""
    }

    func chooseGameLibraryPath() {
        let panel = NSOpenPanel()
        panel.title = L.selectGamesLocation.resolve(in: language)
        panel.prompt = L.select.resolve(in: language)
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true

        if let selectedGameLibraryPath {
            panel.directoryURL = URL(fileURLWithPath: selectedGameLibraryPath)
        }

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        let selectedPath = selectedURL.path
        gameLibraryPath = selectedPath
        statusText = L.gameLibraryConfiguredAt(selectedPath).resolve(in: language)
    }

    func clearGameLibraryPath() {
        gameLibraryPath = ""
        statusText = L.gameLibraryRestoredDefault.resolve(in: language)
    }

    func openGameLibraryFolder() {
        guard let selectedGameLibraryPath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: selectedGameLibraryPath))
    }

    func openSelectedGameFolder() {
        guard let selectedGame else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: selectedGame.installDirectoryPath))
    }

    func refreshGamepads() {
        gamepadMonitor?.refreshNow()
    }

    func openPrefixFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: environment.prefixPath))
    }

    func openLogsFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: environment.logsPath))
    }

    func openAppHomeFolder() {
        guard !environment.appHomePath.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: environment.appHomePath))
    }

    func openHomebrewInstallGuide() {
        guard let url = URL(string: "https://brew.sh") else { return }
        NSWorkspace.shared.open(url)
    }

    func uninstallSteavium(keepData: Bool) {
        let fileManager = FileManager.default
        let appSupportPath = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Steavium")

        // Remove app support data (prefixes, logs, cache, settings) unless user wants to keep data
        if !keepData {
            try? fileManager.removeItem(at: appSupportPath)
        }

        // Remove UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        UserDefaults.standard.removePersistentDomain(forName: "com.steavium.app")

        // Remove saved application state
        let savedState = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Saved Application State/com.steavium.app.savedState")
        try? fileManager.removeItem(at: savedState)

        // Remove caches
        let cachesPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/com.steavium.app")
        try? fileManager.removeItem(at: cachesPath)

        // Move the .app bundle to trash (if running from /Applications)
        let appBundlePath = Bundle.main.bundlePath
        if appBundlePath.contains("/Applications/") {
            let appURL = URL(fileURLWithPath: appBundlePath)
            try? fileManager.trashItem(at: appURL, resultingItemURL: nil)
        }

        // Quit the app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }

    func installFFmpegDependency() {
        runAction(
            title: L.ffmpegInstallation.resolve(in: language),
            refreshPreflightAfterCompletion: true
        ) { manager in
            try await manager.installFFmpegDependency()
        }
    }

    func exportDiagnosticsBundle() {
        guard !isBusy else { return }

        let title = L.diagnosticsExport.resolve(in: language)
        isBusy = true
        statusText = L.inProgress(title).resolve(in: language)

        Task {
            do {
                let archiveURL = try await manager.createDiagnosticsArchive(
                    selectedBackend: graphicsBackend,
                    inAppConsoleLog: logs,
                    preflightReport: preflightReport
                )

                let panel = NSSavePanel()
                panel.title = L.exportDiagnostics.resolve(in: language)
                panel.prompt = L.save.resolve(in: language)
                panel.nameFieldStringValue = archiveURL.lastPathComponent
                panel.canCreateDirectories = true
                panel.allowedContentTypes = [.zip]

                if panel.runModal() == .OK, let destinationURL = panel.url {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: archiveURL, to: destinationURL)
                    statusText = L.diagnosticsExportedTo(destinationURL.path).resolve(in: language)
                    appendLog(
                        section: title,
                        output: L.diagnosticsPackageSavedAt(destinationURL.path).resolve(in: language)
                    )
                } else {
                    statusText = L.diagnosticsExportCanceled.resolve(in: language)
                    appendLog(
                        section: title,
                        output: L.exportCanceledByUser.resolve(in: language)
                    )
                }
            } catch {
                statusText = L.failed(title).resolve(in: language)
                appendLog(
                    section: L.errorSuffix(title).resolve(in: language),
                    output: localizedErrorDescription(for: error)
                )
            }
            isBusy = false
        }
    }

    private func runAction(
        title: String,
        refreshPreflightAfterCompletion: Bool = false,
        operation: @escaping (any SteamManaging) async throws -> String
    ) {
        guard !isBusy else { return }

        isBusy = true
        statusText = L.inProgress(title).resolve(in: language)

        Task {
            do {
                let output = try await operation(manager)
                environment = await manager.snapshot()
                if refreshPreflightAfterCompletion {
                    preflightReport = await manager.runtimePreflightReport()
                }
                await refreshGameLibraryState(forceRefresh: false)
                statusText = L.completed(title).resolve(in: language)
                appendLog(section: title, output: output)
            } catch {
                environment = await manager.snapshot()
                if refreshPreflightAfterCompletion {
                    preflightReport = await manager.runtimePreflightReport()
                }
                await refreshGameLibraryState(forceRefresh: false)
                statusText = L.failed(title).resolve(in: language)
                appendLog(
                    section: L.errorSuffix(title).resolve(in: language),
                    output: localizedErrorDescription(for: error)
                )
            }
            isBusy = false
        }
    }

    private func refreshPreflightReport() async {
        preflightReport = await manager.runtimePreflightReport()
    }

    private func launchSteamNow(runningPolicy: SteamRunningPolicy, backend: GraphicsBackend) {
        guard !isBusy else { return }

        let gameLibraryPath = selectedGameLibraryPath
        let title = L.steamLaunch.resolve(in: language)
        isBusy = true
        launchPhase = .preparingEnvironment
        statusText = L.launchPhasePreparing.resolve(in: language)

        Task {
            defer {
                isBusy = false
                // Clear phase after a brief moment so the user sees the final state
                Task { @MainActor in
                    if launchPhase == .steamDetected {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                    }
                    launchPhase = nil
                }
            }

            do {
                // Phase 1: Spawning
                launchPhase = .spawningProcess
                statusText = L.launchPhaseSpawning.resolve(in: language)

                let output = try await manager.launchSteamDetached(
                    graphicsBackend: backend,
                    runningPolicy: runningPolicy,
                    gameLibraryPath: gameLibraryPath
                )

                appendLog(section: title, output: output)

                // Phase 2: Wait for Steam process to start, then for its window to appear
                launchPhase = .waitingForSteam(elapsedSeconds: 0)
                statusText = L.launchPhaseWaiting(0).resolve(in: language)

                let liveLogPath = "\(environment.logsPath)/steam-live.log"
                var lastLogSize: UInt64 = currentFileSize(at: liveLogPath)
                let maxWaitProcess = 60   // Max seconds to wait for the process
                let maxWaitWindow = 90    // Max total seconds to wait for the window
                var elapsed = 0
                var processFound = false
                var windowFound = false
                var processFoundAtSecond = 0

                // Sub-phase A: Wait for the Steam *process* to appear
                while elapsed < maxWaitProcess && !processFound {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    elapsed += 1
                    launchPhase = .waitingForSteam(elapsedSeconds: elapsed)
                    statusText = L.launchPhaseWaiting(elapsed).resolve(in: language)

                    tailLiveLog(liveLogPath: liveLogPath, lastLogSize: &lastLogSize, title: title)

                    if await manager.isSteamRunning() {
                        processFound = true
                        processFoundAtSecond = elapsed
                    }
                }

                // Sub-phase B: Process found — now wait for a visible *window*
                if processFound {
                    var windowElapsed = 0
                    launchPhase = .steamProcessStarted(elapsedSeconds: 0)
                    statusText = L.launchPhaseProcessStarted(0).resolve(in: language)

                    while elapsed < maxWaitWindow && !windowFound {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        elapsed += 1
                        windowElapsed += 1
                        launchPhase = .steamProcessStarted(elapsedSeconds: windowElapsed)
                        statusText = L.launchPhaseProcessStarted(windowElapsed).resolve(in: language)

                        tailLiveLog(liveLogPath: liveLogPath, lastLogSize: &lastLogSize, title: title)

                        if await manager.isSteamWindowVisible() {
                            windowFound = true
                        }
                    }
                }

                // Final log tail
                tailLiveLog(liveLogPath: liveLogPath, lastLogSize: &lastLogSize, title: title)

                if windowFound {
                    launchPhase = .steamDetected
                    statusText = L.steamLaunchSuccess.resolve(in: language)
                } else if processFound {
                    // Process exists but window never appeared — still report as
                    // launched but warn the user it may take more time
                    launchPhase = .steamDetected
                    statusText = L.steamLaunchTimedOut.resolve(in: language)
                } else {
                    launchPhase = nil
                    statusText = L.steamLaunchTimedOut.resolve(in: language)
                }

                environment = await manager.snapshot()
                await refreshGameLibraryState(forceRefresh: false)

            } catch {
                environment = await manager.snapshot()
                await refreshGameLibraryState(forceRefresh: false)
                statusText = L.failed(title).resolve(in: language)
                appendLog(
                    section: L.errorSuffix(title).resolve(in: language),
                    output: localizedErrorDescription(for: error)
                )
                launchPhase = nil
            }
        }
    }

    /// Returns the current file size, or 0 if the file doesn't exist.
    private nonisolated func currentFileSize(at path: String) -> UInt64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? UInt64 else {
            return 0
        }
        return size
    }

    /// Reads new bytes appended to a file after the given offset.
    /// Returns the trimmed content and the new file size, or nil on failure.
    private nonisolated func readNewLogContent(at path: String, afterOffset: UInt64) -> (String, UInt64)? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }

        let endOffset = handle.seekToEndOfFile()
        guard endOffset > afterOffset else { return nil }

        handle.seek(toFileOffset: afterOffset)
        let data = handle.readData(ofLength: Int(endOffset - afterOffset))
        let content = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return (content, endOffset)
    }

    /// Tails the live log file and appends new content to the log panel.
    private func tailLiveLog(liveLogPath: String, lastLogSize: inout UInt64, title: String) {
        let newLogContent = readNewLogContent(at: liveLogPath, afterOffset: lastLogSize)
        if let (content, newSize) = newLogContent {
            lastLogSize = newSize
            if !content.isEmpty {
                appendLog(section: "\(title) [live]", output: content)
            }
        }
    }

    private func refreshGameLibraryState(forceRefresh: Bool) async {
        let state = await manager.gameLibraryState(forceRefresh: forceRefresh)
        profilesByAppID = Dictionary(uniqueKeysWithValues: state.profiles.map { ($0.appID, $0) })
        installedGames = state.games

        if let selectedGameID, installedGames.contains(where: { $0.appID == selectedGameID }) {
            loadEditorForSelectedGame()
        } else {
            selectedGameID = installedGames.first?.appID
            if selectedGameID == nil {
                profileEditor = .empty
            }
        }
    }

    private func loadEditorForSelectedGame() {
        guard let selectedGame else {
            profileEditor = .empty
            return
        }
        let profile = profilesByAppID[selectedGame.appID]
        profileEditor = GameProfileEditorState(game: selectedGame, profile: profile)
    }

    private func refreshEditorPresetFromFlags() {
        guard var profile = profileEditor.makeProfile() else { return }
        profile.refreshPresetFromFlags()
        mutateProfileEditor { editor in
            editor.preset = profile.preset
        }
    }

    private func applyProfileToEditor(_ profile: GameCompatibilityProfile) {
        mutateProfileEditor { editor in
            editor.preset = profile.preset
            editor.compatibilityMode = profile.compatibilityMode
            editor.forceWindowed = profile.forceWindowed
            editor.force640x480 = profile.force640x480
            editor.reducedColorMode = profile.reducedColorMode
            editor.highDPIOverrideMode = profile.highDPIOverrideMode
            editor.disableFullscreenOptimizations = profile.disableFullscreenOptimizations
            editor.runAsAdmin = profile.runAsAdmin
        }
    }

    private func mutateProfileEditor(_ mutation: (inout GameProfileEditorState) -> Void) {
        var updated = profileEditor
        mutation(&updated)
        profileEditor = updated
    }

    private var selectedGameLibraryPath: String? {
        let trimmed = gameLibraryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var selectedGame: InstalledGame? {
        guard let selectedGameID else { return nil }
        return installedGames.first(where: { $0.appID == selectedGameID })
    }

    var selectedGameExecutableCandidates: [GameExecutableCandidate] {
        selectedGame?.executableCandidates ?? []
    }

    var selectedGameHasSavedProfile: Bool {
        guard let selectedGameID else { return false }
        return profilesByAppID[selectedGameID] != nil
    }

    func hasSavedProfile(appID: Int) -> Bool {
        profilesByAppID[appID] != nil
    }

    var preflightSummary: String {
        guard !preflightReport.checks.isEmpty else {
            return L.preflightNotRunYet.resolve(in: language)
        }

        let failed = preflightReport.checks.filter { $0.status == .failed }.count
        let warning = preflightReport.checks.filter { $0.status == .warning }.count
        let ok = preflightReport.checks.filter { $0.status == .ok }.count

        return L.preflightSummary(ok: ok, warnings: warning, failed: failed).resolve(in: language)
    }

    var preflightHomebrewAvailable: Bool {
        preflightReport.check(for: .homebrew)?.status == .ok
    }

    var gameLibrarySummary: String {
        selectedGameLibraryPath ?? L.defaultInsidePrefix.resolve(in: language)
    }

    var gameProfilesSummary: String {
        L.gameProfilesSummary(games: installedGames.count, profiles: profilesByAppID.count).resolve(in: language)
    }

    var gamepadSummary: String {
        guard !connectedGamepads.isEmpty else {
            return L.noneDetected.resolve(in: language)
        }

        let names = connectedGamepads.map { device in
            switch device.source {
            case .gameController:
                return "\(device.name) (GC)"
            case .hid:
                return "\(device.name) (HID)"
            }
        }

        return names.joined(separator: ", ")
    }

    private func appendLog(section: String, output: String) {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmed.isEmpty ? L.noOutput.resolve(in: language) : trimmed
        logs += """
        [\(timestamp())] \(section)
        \(body)

        """

        if logs.count > 80_000 {
            logs = String(logs.suffix(80_000))
        }
    }

    private func timestamp() -> String {
        Self.logTimestampFormatter.string(from: Date())
    }

    private func localizedErrorDescription(for error: Error) -> String {
        if let managerError = error as? SteamManagerError {
            return managerError.errorDescription(in: language)
        }
        return error.localizedDescription
    }
}
