import XCTest
@testable import Steavium

final class GameLaunchOptionsComposerTests: XCTestCase {
    func testMergeAddsManagedSegmentWithoutDroppingUserOptions() {
        let merged = GameLaunchOptionsComposer.merge(
            existing: "-novid -dx11",
            managedSegment: GameLaunchOptionsComposer.managedSegment(forceWindowed: true)
        )

        XCTAssertTrue(merged.contains("-novid"))
        XCTAssertTrue(merged.contains("-dx11"))
        XCTAssertTrue(merged.contains("-windowed"))
        XCTAssertTrue(merged.contains(GameLaunchOptionsComposer.beginMarker))
        XCTAssertTrue(merged.contains(GameLaunchOptionsComposer.endMarker))
    }

    func testMergeReplacesExistingManagedSegment() {
        let initial = "-novid __STEAVIUM_PROFILE_BEGIN__ -windowed __STEAVIUM_PROFILE_END__"
        let merged = GameLaunchOptionsComposer.merge(existing: initial, managedSegment: nil)

        XCTAssertEqual(merged, "-novid")
        XCTAssertFalse(merged.contains("-windowed"))
    }

    func testStripManagedSegmentHandlesMissingEndMarker() {
        let value = "-novid __STEAVIUM_PROFILE_BEGIN__ -windowed"
        let stripped = GameLaunchOptionsComposer.stripManagedSegment(from: value)
        XCTAssertEqual(stripped, "-novid")
    }
}
