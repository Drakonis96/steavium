import Foundation

/// Protocol abstracting the public surface of a game-store manager
/// (Steam, Battle.net, …) so that `StoreViewModel` can be tested
/// with a mock and new store back-ends can be added without
/// touching UI code.
protocol GameStoreManaging: Actor {
    /// Human-readable name shown in the UI (e.g. "Steam").
    var storeName: String { get }

    func snapshot() -> StoreEnvironment
    func gameLibraryState(forceRefresh: Bool) -> GameLibraryState
    func runtimePreflightReport() -> RuntimePreflightReport

    func installPrerequisites() async throws -> String
    func installRuntime() async throws -> String
    func setupStore(gameLibraryPath: String?) async throws -> String
    func launchStoreDetached(
        graphicsBackend: GraphicsBackend,
        runningPolicy: StoreRunningPolicy,
        gameLibraryPath: String?
    ) async throws -> String
    func stopStoreCompletely() async throws -> String
    func isStoreRunning() async -> Bool
    func isStoreWindowVisible() async -> Bool
    func wipeStoreData(clearAccountData: Bool, clearLibraryData: Bool) async throws -> String

    func saveGameCompatibilityProfile(_ profile: GameCompatibilityProfile) async throws -> String
    func removeGameCompatibilityProfile(appID: Int) async throws -> String

    func installFFmpegDependency() async throws -> String
    func createDiagnosticsArchive(
        selectedBackend: GraphicsBackend,
        inAppConsoleLog: String,
        preflightReport: RuntimePreflightReport
    ) async throws -> URL
}

extension SteamManager: GameStoreManaging {}
extension BattleNetManager: GameStoreManaging {}
extension EpicGamesManager: GameStoreManaging {}
extension GogGalaxyManager: GameStoreManaging {}
