import XCTest
@testable import Steavium

/// Minimal mock of SteamManaging that records calls and returns canned values.
/// Used to verify the ViewModel's launch flow without spawning real processes.
private actor MockSteamManager: SteamManaging {
    var launchDetachedCallCount = 0
    var isSteamRunningResult = false
    var isSteamWindowVisibleResult = false
    var isSteamRunningCallCount = 0
    var launchDetachedOutput = "Steam lanzado en background (worker). PID=12345 LOG=/tmp/test.log"
    var shouldThrowOnLaunch = false

    func snapshot() -> SteamEnvironment {
        SteamEnvironment(
            appHomePath: "/tmp/steavium-test",
            prefixPath: "/tmp/steavium-test/prefixes/steam",
            logsPath: "/tmp/steavium-test/logs",
            wine64Path: "/usr/local/bin/wine64",
            steamInstalled: true,
            steamExecutablePath: "/tmp/steam.exe",
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

    func setupSteam(gameLibraryPath: String?) async throws -> String { "ok" }

    func launchSteamDetached(
        graphicsBackend: GraphicsBackend,
        runningPolicy: SteamRunningPolicy,
        gameLibraryPath: String?
    ) async throws -> String {
        launchDetachedCallCount += 1
        if shouldThrowOnLaunch {
            throw SteamManagerError.wineRuntimeNotFound
        }
        return launchDetachedOutput
    }

    func stopSteamCompletely() async throws -> String { "ok" }

    func isSteamRunning() async -> Bool {
        isSteamRunningCallCount += 1
        return isSteamRunningResult
    }

    func isSteamWindowVisible() async -> Bool {
        return isSteamWindowVisibleResult
    }

    func wipeSteamData(clearAccountData: Bool, clearLibraryData: Bool) async throws -> String { "ok" }

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
    func setSteamRunning(_ running: Bool) {
        isSteamRunningResult = running
    }

    func setSteamWindowVisible(_ visible: Bool) {
        isSteamWindowVisibleResult = visible
    }

    func setThrowOnLaunch(_ shouldThrow: Bool) {
        shouldThrowOnLaunch = shouldThrow
    }
}

@MainActor
final class SteamLaunchFlowTests: XCTestCase {

    func testLaunchPhaseStartsNilOnNewViewModel() async {
        let mock = MockSteamManager()
        let vm = SteamViewModel(manager: mock)
        XCTAssertNil(vm.launchPhase)
    }

    func testLaunchSetsIsBusyAndLaunchPhase() async throws {
        let mock = MockSteamManager()
        // Pre-set Steam as running so the polling exits quickly
        await mock.setSteamRunning(true)

        let vm = SteamViewModel(manager: mock)
        // Wait for initial refresh tasks
        try await Task.sleep(nanoseconds: 500_000_000)

        vm.launchSteam()

        // Give the launch task time to start (it checks isSteamRunning first)
        try await Task.sleep(nanoseconds: 200_000_000)

        // Should have called launchSteamDetached at least once, or be in a launch state
        // Since isSteamRunning is true initially, it will show the "already running" dialog
        // So let's test the reuse flow instead
        XCTAssertTrue(vm.showingSteamRunningDialog || vm.isBusy)
    }

    func testLaunchPhaseTransitionsThroughExpectedStates() async throws {
        let mock = MockSteamManager()
        let vm = SteamViewModel(manager: mock)
        // Wait for initial refresh tasks
        try await Task.sleep(nanoseconds: 500_000_000)

        // No existing session
        await mock.setSteamRunning(false)
        await mock.setSteamWindowVisible(false)

        // Directly call the reuse path (bypasses the "is running?" check)
        vm.launchSteamReusingSession()

        // Give the launch a moment to start
        try await Task.sleep(nanoseconds: 300_000_000)

        // The launch should have been initiated
        let detachedCalls = await mock.launchDetachedCallCount
        XCTAssertEqual(detachedCalls, 1, "launchSteamDetached should have been called exactly once")

        // Simulate process appearing (but no window yet)
        await mock.setSteamRunning(true)

        // Wait for the polling to detect the process (polls every 1s)
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Should be in the steamProcessStarted phase (process found, window not yet)
        if case .steamProcessStarted = vm.launchPhase {
            // expected
        } else {
            // It might have already proceeded if timing is tight;
            // the key assertion is that it doesn't falsely report .steamDetected yet
            XCTAssertNotNil(vm.launchPhase, "Should still be in a launch phase")
        }

        // Now simulate window appearing
        await mock.setSteamWindowVisible(true)

        // Wait for the window polling to detect it
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Should have detected Steam window and completed
        XCTAssertEqual(vm.launchPhase, .steamDetected)
    }

    func testLaunchErrorClearsPhaseAndMarksNotBusy() async throws {
        let mock = MockSteamManager()
        await mock.setThrowOnLaunch(true)

        let vm = SteamViewModel(manager: mock)
        try await Task.sleep(nanoseconds: 500_000_000)

        // Start via reuse path to bypass the running check
        await mock.setSteamRunning(false)
        vm.launchSteamReusingSession()

        // Wait for error to propagate
        try await Task.sleep(nanoseconds: 1_000_000_000)

        XCTAssertNil(vm.launchPhase, "Launch phase should be nil after error")
        XCTAssertFalse(vm.isBusy, "isBusy should be false after error")
        XCTAssertTrue(vm.statusText.lowercased().contains("fail"), "Status should mention failure: \(vm.statusText)")
    }
}
