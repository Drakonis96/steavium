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

    func testWaitingForStoreProgressIncreasesWithTime() {
        let early = LaunchPhase.waitingForStore(elapsedSeconds: 1)
        let mid = LaunchPhase.waitingForStore(elapsedSeconds: 10)
        let late = LaunchPhase.waitingForStore(elapsedSeconds: 30)

        XCTAssertGreaterThan(mid.estimatedProgress, early.estimatedProgress)
        XCTAssertGreaterThan(late.estimatedProgress, mid.estimatedProgress)
    }

    func testWaitingForStoreProgressNeverExceedsNinetyFive() {
        // Even at very large elapsed times, progress should stay < 1.0
        let extreme = LaunchPhase.waitingForStore(elapsedSeconds: 300)
        XCTAssertLessThan(extreme.estimatedProgress, 1.0)
    }

    func testWaitingForStoreProgressStartsAboveSpawning() {
        let spawning = LaunchPhase.spawningProcess
        let waitingStart = LaunchPhase.waitingForStore(elapsedSeconds: 0)
        // At elapsed=0, the waiting phase should equal spawning (base = 0.25)
        XCTAssertEqual(waitingStart.estimatedProgress, spawning.estimatedProgress, accuracy: 0.001)
    }

    func testStoreDetectedProgressIsOne() {
        let phase = LaunchPhase.storeDetected
        XCTAssertEqual(phase.estimatedProgress, 1.0, accuracy: 0.001)
    }

    func testProgressIsMonotonicallyIncreasing() {
        let phases: [LaunchPhase] = [
            .preparingEnvironment,
            .spawningProcess,
            .waitingForStore(elapsedSeconds: 0),
            .waitingForStore(elapsedSeconds: 5),
            .waitingForStore(elapsedSeconds: 15),
            .waitingForStore(elapsedSeconds: 30),
            .storeProcessStarted(elapsedSeconds: 0),
            .storeProcessStarted(elapsedSeconds: 5),
            .storeProcessStarted(elapsedSeconds: 15),
            .storeProcessStarted(elapsedSeconds: 30),
            .storeDetected
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
            .waitingForStore(elapsedSeconds: 5),
            .storeProcessStarted(elapsedSeconds: 3),
            .storeDetected
        ]

        for phase in phases {
            let english = phase.title(in: .english)
            let spanish = phase.title(in: .spanish)
            XCTAssertFalse(english.isEmpty, "English title should not be empty for \(phase)")
            XCTAssertFalse(spanish.isEmpty, "Spanish title should not be empty for \(phase)")
        }
    }

    func testWaitingTitleIncludesElapsedSeconds() {
        let phase = LaunchPhase.waitingForStore(elapsedSeconds: 12)
        let title = phase.title(in: .english)
        XCTAssertTrue(title.contains("12"), "Title should contain the elapsed seconds: \(title)")
    }

    // MARK: - Equatable

    func testEquatableForSamePhase() {
        XCTAssertEqual(LaunchPhase.preparingEnvironment, LaunchPhase.preparingEnvironment)
        XCTAssertEqual(LaunchPhase.spawningProcess, LaunchPhase.spawningProcess)
        XCTAssertEqual(LaunchPhase.storeDetected, LaunchPhase.storeDetected)
        XCTAssertEqual(
            LaunchPhase.waitingForStore(elapsedSeconds: 5),
            LaunchPhase.waitingForStore(elapsedSeconds: 5)
        )
    }

    func testEquatableForDifferentElapsed() {
        XCTAssertNotEqual(
            LaunchPhase.waitingForStore(elapsedSeconds: 5),
            LaunchPhase.waitingForStore(elapsedSeconds: 10)
        )
    }

    func testEquatableForDifferentPhases() {
        XCTAssertNotEqual(LaunchPhase.preparingEnvironment, LaunchPhase.spawningProcess)
        XCTAssertNotEqual(LaunchPhase.spawningProcess, LaunchPhase.storeDetected)
        XCTAssertNotEqual(LaunchPhase.storeProcessStarted(elapsedSeconds: 5), LaunchPhase.waitingForStore(elapsedSeconds: 5))
    }

    // MARK: - storeProcessStarted

    func testProcessStartedProgressIncreasesWithTime() {
        let early = LaunchPhase.storeProcessStarted(elapsedSeconds: 1)
        let mid = LaunchPhase.storeProcessStarted(elapsedSeconds: 10)
        let late = LaunchPhase.storeProcessStarted(elapsedSeconds: 30)

        XCTAssertGreaterThan(mid.estimatedProgress, early.estimatedProgress)
        XCTAssertGreaterThan(late.estimatedProgress, mid.estimatedProgress)
    }

    func testProcessStartedProgressNeverReachesOne() {
        let extreme = LaunchPhase.storeProcessStarted(elapsedSeconds: 300)
        XCTAssertLessThan(extreme.estimatedProgress, 1.0)
    }

    func testProcessStartedStartsAboveWaitingMax() {
        // storeProcessStarted(0) should be >= waitingForStore at any reasonable time
        let waitingLate = LaunchPhase.waitingForStore(elapsedSeconds: 60)
        let processStart = LaunchPhase.storeProcessStarted(elapsedSeconds: 0)
        XCTAssertGreaterThanOrEqual(
            processStart.estimatedProgress,
            waitingLate.estimatedProgress,
            "Process started should begin above the max of waiting phase"
        )
    }

    func testProcessStartedTitleIncludesElapsedSeconds() {
        let phase = LaunchPhase.storeProcessStarted(elapsedSeconds: 7)
        let title = phase.title(in: .english)
        XCTAssertTrue(title.contains("7"), "Title should contain the elapsed seconds: \(title)")
    }
}
