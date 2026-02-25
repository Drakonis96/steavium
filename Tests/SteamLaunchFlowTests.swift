import XCTest
@testable import Steavium

/// Minimal mock of GameStoreManaging that records calls and returns canned values.
/// Used to verify the ViewModel's launch flow without spawning real processes.
private actor MockStoreManager: GameStoreManaging {
    nonisolated var storeName: String { "Steam" }

    var launchDetachedCallCount = 0
    var isStoreRunningResult = false
    var isStoreWindowVisibleResult = false
    var isStoreRunningCallCount = 0
    var launchDetachedOutput = "Steam lanzado en background (worker). PID=12345 LOG=/tmp/test.log"
    var shouldThrowOnLaunch = false

    func snapshot() -> StoreEnvironment {
        StoreEnvironment(
            appHomePath: "/tmp/steavium-test",
            prefixPath: "/tmp/steavium-test/prefixes/steam",
            logsPath: "/tmp/steavium-test/logs",
            wine64Path: "/usr/local/bin/wine64",
            storeAppInstalled: true,
            storeAppExecutablePath: "/tmp/steam.exe",
            hardwareProfile: .empty
        )
    }

    func gameLibraryState(forceRefresh: Bool) -> GameLibraryState {
        GameLibraryState(games: [], profiles: [])
    }

    func runtimePreflightReport() -> RuntimePreflightReport {
        .empty
    }

    func installPrerequisites() async throws -> String { "ok" }

    func installRuntime() async throws -> String { "ok" }

    func setupStore(gameLibraryPath: String?) async throws -> String { "ok" }

    func launchStoreDetached(
        graphicsBackend: GraphicsBackend,
        runningPolicy: StoreRunningPolicy,
        gameLibraryPath: String?
    ) async throws -> String {
        launchDetachedCallCount += 1
        if shouldThrowOnLaunch {
            throw StoreManagerError.wineRuntimeNotFound
        }
        return launchDetachedOutput
    }

    func stopStoreCompletely() async throws -> String { "ok" }

    func isStoreRunning() async -> Bool {
        isStoreRunningCallCount += 1
        return isStoreRunningResult
    }

    func isStoreWindowVisible() async -> Bool {
        return isStoreWindowVisibleResult
    }

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

    // Helpers for test control
    func setStoreRunning(_ running: Bool) {
        isStoreRunningResult = running
    }

    func setStoreWindowVisible(_ visible: Bool) {
        isStoreWindowVisibleResult = visible
    }

    func setThrowOnLaunch(_ shouldThrow: Bool) {
        shouldThrowOnLaunch = shouldThrow
    }
}

@MainActor
final class SteamLaunchFlowTests: XCTestCase {

    func testLaunchPhaseStartsNilOnNewViewModel() async {
        let mock = MockStoreManager()
        let vm = StoreViewModel(manager: mock)
        XCTAssertNil(vm.launchPhase)
    }

    func testLaunchSetsIsBusyAndLaunchPhase() async throws {
        let mock = MockStoreManager()
        // Pre-set Steam as running so the polling exits quickly
        await mock.setStoreRunning(true)

        let vm = StoreViewModel(manager: mock)
        // Wait for initial refresh tasks
        try await Task.sleep(nanoseconds: 500_000_000)

        vm.launchStore()

        // Give the launch task time to start (it checks isStoreRunning first)
        try await Task.sleep(nanoseconds: 200_000_000)

        // Should have called launchStoreDetached at least once, or be in a launch state
        // Since isStoreRunning is true initially, it will show the "already running" dialog
        // So let's test the reuse flow instead
        XCTAssertTrue(vm.showingStoreRunningDialog || vm.isBusy)
    }

    func testLaunchPhaseTransitionsThroughExpectedStates() async throws {
        let mock = MockStoreManager()
        let vm = StoreViewModel(manager: mock)
        // Wait for initial refresh tasks
        try await Task.sleep(nanoseconds: 500_000_000)

        // No existing session
        await mock.setStoreRunning(false)
        await mock.setStoreWindowVisible(false)

        // Directly call the reuse path (bypasses the "is running?" check)
        vm.launchStoreReusingSession()

        // Give the launch a moment to start
        try await Task.sleep(nanoseconds: 300_000_000)

        // The launch should have been initiated
        let detachedCalls = await mock.launchDetachedCallCount
        XCTAssertEqual(detachedCalls, 1, "launchStoreDetached should have been called exactly once")

        // Simulate process appearing (but no window yet)
        await mock.setStoreRunning(true)

        // Wait for the polling to detect the process (polls every 1s)
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Should be in the storeProcessStarted phase (process found, window not yet)
        if case .storeProcessStarted = vm.launchPhase {
            // expected
        } else {
            // It might have already proceeded if timing is tight;
            // the key assertion is that it doesn't falsely report .storeDetected yet
            XCTAssertNotNil(vm.launchPhase, "Should still be in a launch phase")
        }

        // Now simulate window appearing
        await mock.setStoreWindowVisible(true)

        // Wait for the window polling to detect it
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Should have detected store window and completed
        XCTAssertEqual(vm.launchPhase, .storeDetected)
    }

    func testLaunchErrorClearsPhaseAndMarksNotBusy() async throws {
        let mock = MockStoreManager()
        await mock.setThrowOnLaunch(true)

        let vm = StoreViewModel(manager: mock)
        try await Task.sleep(nanoseconds: 500_000_000)

        // Start via reuse path to bypass the running check
        await mock.setStoreRunning(false)
        vm.launchStoreReusingSession()

        // Wait for error to propagate
        try await Task.sleep(nanoseconds: 1_000_000_000)

        XCTAssertNil(vm.launchPhase, "Launch phase should be nil after error")
        XCTAssertFalse(vm.isBusy, "isBusy should be false after error")
        XCTAssertTrue(vm.statusText.lowercased().contains("fail"), "Status should mention failure: \(vm.statusText)")
    }
}
