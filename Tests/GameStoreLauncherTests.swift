import XCTest
@testable import Steavium

final class GameStoreLauncherTests: XCTestCase {

    // MARK: - CaseIterable

    func testAllCasesContainsFourLaunchers() {
        XCTAssertEqual(GameStoreLauncher.allCases.count, 4)
    }

    func testAllCasesOrder() {
        let expected: [GameStoreLauncher] = [.steam, .battleNet, .epicGames, .gogGalaxy]
        XCTAssertEqual(GameStoreLauncher.allCases, expected)
    }

    // MARK: - Labels

    func testSteamLabel() {
        XCTAssertEqual(GameStoreLauncher.steam.label, "Steam")
    }

    func testBattleNetLabel() {
        XCTAssertEqual(GameStoreLauncher.battleNet.label, "Battle.net")
    }

    func testEpicGamesLabel() {
        XCTAssertEqual(GameStoreLauncher.epicGames.label, "Epic Games")
    }

    func testGogGalaxyLabel() {
        XCTAssertEqual(GameStoreLauncher.gogGalaxy.label, "GOG Galaxy")
    }

    // MARK: - Identifiable

    func testIdentifiableIdsAreUnique() {
        let ids = GameStoreLauncher.allCases.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "All launcher IDs should be unique")
    }

    func testIdMatchesRawValue() {
        for launcher in GameStoreLauncher.allCases {
            XCTAssertEqual(launcher.id, launcher.rawValue)
        }
    }

    // MARK: - RawValue round-trip

    func testRawValueRoundTrip() {
        for launcher in GameStoreLauncher.allCases {
            let restored = GameStoreLauncher(rawValue: launcher.rawValue)
            XCTAssertEqual(restored, launcher)
        }
    }

    func testInvalidRawValueReturnsNil() {
        XCTAssertNil(GameStoreLauncher(rawValue: "origin"))
    }

    // MARK: - Title

    func testTitleMatchesLabelForBothLanguages() {
        for launcher in GameStoreLauncher.allCases {
            XCTAssertEqual(launcher.title(in: .english), launcher.label)
            XCTAssertEqual(launcher.title(in: .spanish), launcher.label)
        }
    }

    // MARK: - Labels are non-empty

    func testAllLabelsAreNonEmpty() {
        for launcher in GameStoreLauncher.allCases {
            XCTAssertFalse(launcher.label.isEmpty, "\(launcher) should have a non-empty label")
        }
    }
}
