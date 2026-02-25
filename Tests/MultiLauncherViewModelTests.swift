import XCTest
@testable import Steavium

/// Minimal mock that records calls — reusable across all launcher tests.
private actor StubStoreManager: GameStoreManaging {
    let _storeName: String
    nonisolated var storeName: String { _storeName }

    init(storeName: String = "Stub") {
        self._storeName = storeName
    }

    func snapshot() -> StoreEnvironment {
        StoreEnvironment(
            appHomePath: "/tmp/steavium-test",
            prefixPath: "/tmp/steavium-test/prefixes/stub",
            logsPath: "/tmp/steavium-test/logs",
            wine64Path: "/usr/local/bin/wine64",
            storeAppInstalled: false,
            storeAppExecutablePath: nil,
            hardwareProfile: .empty
        )
    }

    func gameLibraryState(forceRefresh: Bool) -> GameLibraryState {
        GameLibraryState(games: [], profiles: [])
    }

    func runtimePreflightReport() -> RuntimePreflightReport { .empty }

    func installPrerequisites() async throws -> String { "ok" }
    func installRuntime() async throws -> String { "ok" }
    func setupStore(gameLibraryPath: String?) async throws -> String { "ok" }
    func launchStoreDetached(
        graphicsBackend: GraphicsBackend,
        runningPolicy: StoreRunningPolicy,
        gameLibraryPath: String?
    ) async throws -> String { "ok" }
    func stopStoreCompletely() async throws -> String { "ok" }
    func isStoreRunning() async -> Bool { false }
    func isStoreWindowVisible() async -> Bool { false }
    func wipeStoreData(clearAccountData: Bool, clearLibraryData: Bool) async throws -> String { "ok" }
    func saveGameCompatibilityProfile(_ profile: GameCompatibilityProfile) async throws -> String { "ok" }
    func removeGameCompatibilityProfile(appID: Int) async throws -> String { "ok" }
    func installFFmpegDependency() async throws -> String { "ok" }
    func createDiagnosticsArchive(
        selectedBackend: GraphicsBackend,
        inAppConsoleLog: String,
        preflightReport: RuntimePreflightReport
    ) async throws -> URL {
        URL(fileURLWithPath: "/tmp/diag.zip")
    }
}

@MainActor
final class MultiLauncherViewModelTests: XCTestCase {

    // MARK: - Default state

    func testDefaultLauncherIsSteam() async throws {
        // Clear any persisted preference
        UserDefaults.standard.removeObject(forKey: "steavium.selected_launcher")

        let mock = StubStoreManager(storeName: "Steam")
        let vm = StoreViewModel(manager: mock)
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(vm.selectedLauncher, .steam)
        XCTAssertEqual(vm.currentStoreName, "Steam")
    }

    // MARK: - Manager creation for each launcher

    func testCreateManagerForSteamReturnsSteamManager() async {
        let mock = StubStoreManager(storeName: "Steam")
        let vm = StoreViewModel(manager: mock)
        // The default manager storeName should match
        let name = await vm.manager.storeName
        XCTAssertEqual(name, "Steam")
    }

    func testSwitchToBattleNetUpdatesStoreName() async throws {
        UserDefaults.standard.removeObject(forKey: "steavium.selected_launcher")
        let mock = StubStoreManager(storeName: "Steam")
        let vm = StoreViewModel(manager: mock)
        try await Task.sleep(nanoseconds: 300_000_000)

        vm.selectedLauncher = .battleNet
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(vm.currentStoreName, "Battle.net")
        let name = await vm.manager.storeName
        XCTAssertEqual(name, "Battle.net")
    }

    func testSwitchToEpicGamesUpdatesStoreName() async throws {
        UserDefaults.standard.removeObject(forKey: "steavium.selected_launcher")
        let mock = StubStoreManager(storeName: "Steam")
        let vm = StoreViewModel(manager: mock)
        try await Task.sleep(nanoseconds: 300_000_000)

        vm.selectedLauncher = .epicGames
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(vm.currentStoreName, "Epic Games")
        let name = await vm.manager.storeName
        XCTAssertEqual(name, "Epic Games")
    }

    func testSwitchToGogGalaxyUpdatesStoreName() async throws {
        UserDefaults.standard.removeObject(forKey: "steavium.selected_launcher")
        let mock = StubStoreManager(storeName: "Steam")
        let vm = StoreViewModel(manager: mock)
        try await Task.sleep(nanoseconds: 300_000_000)

        vm.selectedLauncher = .gogGalaxy
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(vm.currentStoreName, "GOG Galaxy")
        let name = await vm.manager.storeName
        XCTAssertEqual(name, "GOG Galaxy")
    }

    // MARK: - Persistence

    func testSelectedLauncherIsPersisted() async throws {
        UserDefaults.standard.removeObject(forKey: "steavium.selected_launcher")
        let mock = StubStoreManager(storeName: "Steam")
        let vm = StoreViewModel(manager: mock)
        try await Task.sleep(nanoseconds: 300_000_000)

        vm.selectedLauncher = .epicGames
        try await Task.sleep(nanoseconds: 200_000_000)

        let saved = UserDefaults.standard.string(forKey: "steavium.selected_launcher")
        XCTAssertEqual(saved, "epicGames")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "steavium.selected_launcher")
    }

    // MARK: - Switch does not happen while busy

    func testSwitchWhileBusyDoesNotChangeManager() async throws {
        UserDefaults.standard.removeObject(forKey: "steavium.selected_launcher")
        let mock = StubStoreManager(storeName: "Steam")
        let vm = StoreViewModel(manager: mock)
        try await Task.sleep(nanoseconds: 300_000_000)

        // Simulate busy state
        vm.isBusy = true

        let previousName = await vm.manager.storeName
        vm.selectedLauncher = .battleNet
        try await Task.sleep(nanoseconds: 300_000_000)

        // Manager should remain unchanged because we were busy
        let currentName = await vm.manager.storeName
        XCTAssertEqual(currentName, previousName)

        vm.isBusy = false
        UserDefaults.standard.removeObject(forKey: "steavium.selected_launcher")
    }

    // MARK: - Launch phase resets on switch

    func testSwitchResetsLaunchPhase() async throws {
        UserDefaults.standard.removeObject(forKey: "steavium.selected_launcher")
        let mock = StubStoreManager(storeName: "Steam")
        let vm = StoreViewModel(manager: mock)
        try await Task.sleep(nanoseconds: 300_000_000)

        vm.selectedLauncher = .gogGalaxy
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertNil(vm.launchPhase)
        XCTAssertFalse(vm.isStoreRunning)

        UserDefaults.standard.removeObject(forKey: "steavium.selected_launcher")
    }
}
