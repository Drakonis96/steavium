import XCTest
@testable import Steavium

final class GameProfilePersistenceTests: XCTestCase {
    func testSaveAndLoadProfilesRoundTrip() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("steavium-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let fileURL = tempDirectory.appendingPathComponent("game-profiles.json")
        let profiles = [
            GameCompatibilityProfile(
                appID: 220,
                preset: .legacyVideoSafe,
                executableRelativePath: "hl2.exe",
                compatibilityMode: .windowsXPServicePack3,
                forceWindowed: false,
                force640x480: true,
                reducedColorMode: .colors16Bit,
                highDPIOverrideMode: .application,
                disableFullscreenOptimizations: true,
                runAsAdmin: false
            ),
            GameCompatibilityProfile(
                appID: 570,
                preset: .windowedSafe,
                executableRelativePath: "dota2.exe",
                compatibilityMode: .none,
                forceWindowed: true,
                force640x480: false,
                reducedColorMode: .none,
                highDPIOverrideMode: .none,
                disableFullscreenOptimizations: true,
                runAsAdmin: false
            )
        ]

        try GameProfilePersistence.saveProfiles(profiles, to: fileURL)
        let loaded = try GameProfilePersistence.loadProfiles(from: fileURL)

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.map(\.appID), [220, 570])
        XCTAssertEqual(loaded.first?.preset, .legacyVideoSafe)
        XCTAssertEqual(loaded.first?.compatibilityMode, .windowsXPServicePack3)
        XCTAssertEqual(loaded.first?.reducedColorMode, .colors16Bit)
        XCTAssertEqual(loaded.first?.highDPIOverrideMode, .application)
        XCTAssertEqual(loaded.last?.preset, .windowedSafe)
        XCTAssertEqual(loaded.last?.reducedColorMode, GameReducedColorMode.none)
        XCTAssertEqual(loaded.last?.highDPIOverrideMode, GameHighDPIOverrideMode.none)
    }

    func testLoadMissingProfilesReturnsEmpty() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("steavium-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let missing = tempDirectory.appendingPathComponent("missing.json")
        let loaded = try GameProfilePersistence.loadProfiles(from: missing)
        XCTAssertTrue(loaded.isEmpty)
    }

    func testLoadLegacyProfilesMigrates16BitColorFlag() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("steavium-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let legacyJSON = """
        {
          "version" : 1,
          "profiles" : [
            {
              "appID" : 730,
              "disableFullscreenOptimizations" : true,
              "executableRelativePath" : "cs2.exe",
              "force16BitColor" : true,
              "force640x480" : false,
              "forceWindowed" : false,
              "preset" : "custom",
              "runAsAdmin" : false
            }
          ]
        }
        """

        let fileURL = tempDirectory.appendingPathComponent("legacy-game-profiles.json")
        try legacyJSON.write(to: fileURL, atomically: true, encoding: .utf8)

        let loaded = try GameProfilePersistence.loadProfiles(from: fileURL)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.appID, 730)
        XCTAssertEqual(loaded.first?.reducedColorMode, .colors16Bit)
        XCTAssertEqual(loaded.first?.highDPIOverrideMode, GameHighDPIOverrideMode.none)
        XCTAssertEqual(loaded.first?.compatibilityMode, GameCompatibilityMode.none)
    }
}
