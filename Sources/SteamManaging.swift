import Foundation

/// Protocol abstracting the public surface of `SteamManager`
/// so that `SteamViewModel` can be tested with a mock.
protocol SteamManaging: Actor {
    func snapshot() -> SteamEnvironment
    func gameLibraryState(forceRefresh: Bool) -> GameLibraryState
    func runtimePreflightReport() -> RuntimePreflightReport

    func installRuntime() async throws -> String
    func setupSteam(gameLibraryPath: String?) async throws -> String
    func launchSteamDetached(
        graphicsBackend: GraphicsBackend,
        runningPolicy: SteamRunningPolicy,
        gameLibraryPath: String?
    ) async throws -> String
    func stopSteamCompletely() async throws -> String
    func isSteamRunning() async -> Bool
    func isSteamWindowVisible() async -> Bool
    func wipeSteamData(clearAccountData: Bool, clearLibraryData: Bool) async throws -> String

    func saveGameCompatibilityProfile(_ profile: GameCompatibilityProfile) async throws -> String
    func removeGameCompatibilityProfile(appID: Int) async throws -> String

    func installFFmpegDependency() async throws -> String
    func createDiagnosticsArchive(
        selectedBackend: GraphicsBackend,
        inAppConsoleLog: String,
        preflightReport: RuntimePreflightReport
    ) async throws -> URL
}

extension SteamManager: SteamManaging {}
