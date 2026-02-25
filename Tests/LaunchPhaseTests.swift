import XCTest
@testable import Steavium

final class LaunchPhaseTests: XCTestCase {

    // MARK: - Progress estimation

    func testPreparingEnvironmentProgressIsLow() {
        let phase = LaunchPhase.preparingEnvironment
        XCTAssertEqual(phase.estimatedProgress, 0.1, accuracy: 0.001)
    }

    func testSpawningProcessProgressIsQuarter() {
        let phase = LaunchPhase.spawningProcess
        XCTAssertEqual(phase.estimatedProgress, 0.25, accuracy: 0.001)
    }

    func testWaitingForSteamProgressIncreasesWithTime() {
        let early = LaunchPhase.waitingForSteam(elapsedSeconds: 1)
        let mid = LaunchPhase.waitingForSteam(elapsedSeconds: 10)
        let late = LaunchPhase.waitingForSteam(elapsedSeconds: 30)

        XCTAssertGreaterThan(mid.estimatedProgress, early.estimatedProgress)
        XCTAssertGreaterThan(late.estimatedProgress, mid.estimatedProgress)
    }

    func testWaitingForSteamProgressNeverExceedsNinetyFive() {
        // Even at very large elapsed times, progress should stay < 1.0
        let extreme = LaunchPhase.waitingForSteam(elapsedSeconds: 300)
        XCTAssertLessThan(extreme.estimatedProgress, 1.0)
    }

    func testWaitingForSteamProgressStartsAboveSpawning() {
        let spawning = LaunchPhase.spawningProcess
        let waitingStart = LaunchPhase.waitingForSteam(elapsedSeconds: 0)
        // At elapsed=0, the waiting phase should equal spawning (base = 0.25)
        XCTAssertEqual(waitingStart.estimatedProgress, spawning.estimatedProgress, accuracy: 0.001)
    }

    func testSteamDetectedProgressIsOne() {
        let phase = LaunchPhase.steamDetected
        XCTAssertEqual(phase.estimatedProgress, 1.0, accuracy: 0.001)
    }

    func testProgressIsMonotonicallyIncreasing() {
        let phases: [LaunchPhase] = [
            .preparingEnvironment,
            .spawningProcess,
            .waitingForSteam(elapsedSeconds: 0),
            .waitingForSteam(elapsedSeconds: 5),
            .waitingForSteam(elapsedSeconds: 15),
            .waitingForSteam(elapsedSeconds: 30),
            .steamProcessStarted(elapsedSeconds: 0),
            .steamProcessStarted(elapsedSeconds: 5),
            .steamProcessStarted(elapsedSeconds: 15),
            .steamProcessStarted(elapsedSeconds: 30),
            .steamDetected
        ]

        for i in 1..<phases.count {
            XCTAssertGreaterThanOrEqual(
                phases[i].estimatedProgress,
                phases[i - 1].estimatedProgress,
                "Phase \(phases[i]) should have progress >= phase \(phases[i - 1])"
            )
        }
    }

    // MARK: - Localized titles

    func testTitlesAreNonEmptyForBothLanguages() {
        let phases: [LaunchPhase] = [
            .preparingEnvironment,
            .spawningProcess,
            .waitingForSteam(elapsedSeconds: 5),
            .steamProcessStarted(elapsedSeconds: 3),
            .steamDetected
        ]

        for phase in phases {
            let english = phase.title(in: .english)
            let spanish = phase.title(in: .spanish)
            XCTAssertFalse(english.isEmpty, "English title should not be empty for \(phase)")
            XCTAssertFalse(spanish.isEmpty, "Spanish title should not be empty for \(phase)")
        }
    }

    func testWaitingTitleIncludesElapsedSeconds() {
        let phase = LaunchPhase.waitingForSteam(elapsedSeconds: 12)
        let title = phase.title(in: .english)
        XCTAssertTrue(title.contains("12"), "Title should contain the elapsed seconds: \(title)")
    }

    // MARK: - Equatable

    func testEquatableForSamePhase() {
        XCTAssertEqual(LaunchPhase.preparingEnvironment, LaunchPhase.preparingEnvironment)
        XCTAssertEqual(LaunchPhase.spawningProcess, LaunchPhase.spawningProcess)
        XCTAssertEqual(LaunchPhase.steamDetected, LaunchPhase.steamDetected)
        XCTAssertEqual(
            LaunchPhase.waitingForSteam(elapsedSeconds: 5),
            LaunchPhase.waitingForSteam(elapsedSeconds: 5)
        )
    }

    func testEquatableForDifferentElapsed() {
        XCTAssertNotEqual(
            LaunchPhase.waitingForSteam(elapsedSeconds: 5),
            LaunchPhase.waitingForSteam(elapsedSeconds: 10)
        )
    }

    func testEquatableForDifferentPhases() {
        XCTAssertNotEqual(LaunchPhase.preparingEnvironment, LaunchPhase.spawningProcess)
        XCTAssertNotEqual(LaunchPhase.spawningProcess, LaunchPhase.steamDetected)
        XCTAssertNotEqual(LaunchPhase.steamProcessStarted(elapsedSeconds: 5), LaunchPhase.waitingForSteam(elapsedSeconds: 5))
    }

    // MARK: - steamProcessStarted

    func testProcessStartedProgressIncreasesWithTime() {
        let early = LaunchPhase.steamProcessStarted(elapsedSeconds: 1)
        let mid = LaunchPhase.steamProcessStarted(elapsedSeconds: 10)
        let late = LaunchPhase.steamProcessStarted(elapsedSeconds: 30)

        XCTAssertGreaterThan(mid.estimatedProgress, early.estimatedProgress)
        XCTAssertGreaterThan(late.estimatedProgress, mid.estimatedProgress)
    }

    func testProcessStartedProgressNeverReachesOne() {
        let extreme = LaunchPhase.steamProcessStarted(elapsedSeconds: 300)
        XCTAssertLessThan(extreme.estimatedProgress, 1.0)
    }

    func testProcessStartedStartsAboveWaitingMax() {
        // steamProcessStarted(0) should be >= waitingForSteam at any reasonable time
        let waitingLate = LaunchPhase.waitingForSteam(elapsedSeconds: 60)
        let processStart = LaunchPhase.steamProcessStarted(elapsedSeconds: 0)
        XCTAssertGreaterThanOrEqual(
            processStart.estimatedProgress,
            waitingLate.estimatedProgress,
            "Process started should begin above the max of waiting phase"
        )
    }

    func testProcessStartedTitleIncludesElapsedSeconds() {
        let phase = LaunchPhase.steamProcessStarted(elapsedSeconds: 7)
        let title = phase.title(in: .english)
        XCTAssertTrue(title.contains("7"), "Title should contain the elapsed seconds: \(title)")
    }
}
