import XCTest
@testable import Steavium

final class RuntimePreflightTests: XCTestCase {
    func testOverallStatusIsWarningWhenNoChecksExist() {
        let report = RuntimePreflightReport.empty
        XCTAssertEqual(report.overallStatus, .warning)
    }

    func testBlockingFailuresIncludeOnlyBlockingChecks() {
        let report = RuntimePreflightReport(
            generatedAt: Date(),
            checks: [
                RuntimePreflightCheck(
                    kind: .network,
                    status: .failed,
                    detailEnglish: "x",
                    detailSpanish: "x"
                ),
                RuntimePreflightCheck(
                    kind: .ffmpeg,
                    status: .failed,
                    detailEnglish: "x",
                    detailSpanish: "x"
                )
            ]
        )

        XCTAssertEqual(report.blockingFailureKinds, [.network])
        XCTAssertTrue(report.hasBlockingFailures)
    }

    func testCheckLookupByKind() {
        let expected = RuntimePreflightCheck(
            kind: .homebrew,
            status: .ok,
            detailEnglish: "ok",
            detailSpanish: "ok"
        )
        let report = RuntimePreflightReport(
            generatedAt: Date(),
            checks: [expected]
        )

        XCTAssertEqual(report.check(for: .homebrew)?.status, .ok)
        XCTAssertNil(report.check(for: .runtime))
    }
}
