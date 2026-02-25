import XCTest
@testable import Steavium

final class GameLibraryScannerTests: XCTestCase {
    func testDiscoverInstalledGamesParsesManifestAndFindsExecutable() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("steavium-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let steamRoot = tempRoot.appendingPathComponent("Steam", isDirectory: true)
        let steamApps = steamRoot.appendingPathComponent("steamapps", isDirectory: true)
        let common = steamApps.appendingPathComponent("common", isDirectory: true)
        let gameDir = common.appendingPathComponent("Half-Life 2", isDirectory: true)
        try FileManager.default.createDirectory(at: gameDir, withIntermediateDirectories: true)

        let manifest = """
        "AppState"
        {
            "appid"        "220"
            "name"         "Half-Life 2"
            "installdir"   "Half-Life 2"
        }
        """
        let manifestPath = steamApps.appendingPathComponent("appmanifest_220.acf")
        try FileManager.default.createDirectory(at: steamApps, withIntermediateDirectories: true)
        try manifest.write(to: manifestPath, atomically: true, encoding: .utf8)

        let mainExe = gameDir.appendingPathComponent("hl2.exe")
        let uninstallExe = gameDir.appendingPathComponent("uninstall.exe")
        FileManager.default.createFile(atPath: mainExe.path, contents: Data())
        FileManager.default.createFile(atPath: uninstallExe.path, contents: Data())

        let games = GameLibraryScanner.discoverInstalledGames(steamRoot: steamRoot)
        XCTAssertEqual(games.count, 1)
        XCTAssertEqual(games.first?.appID, 220)
        XCTAssertEqual(games.first?.name, "Half-Life 2")
        XCTAssertEqual(games.first?.defaultExecutableRelativePath, "hl2.exe")
    }

    func testLocateLocalConfigFilesReturnsUserConfigFiles() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("steavium-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let steamRoot = tempRoot
        let localConfig = steamRoot
            .appendingPathComponent("userdata", isDirectory: true)
            .appendingPathComponent("12345", isDirectory: true)
            .appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent("localconfig.vdf")
        try FileManager.default.createDirectory(at: localConfig.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "\"UserLocalConfigStore\"{}".write(to: localConfig, atomically: true, encoding: .utf8)

        let files = GameLibraryScanner.locateLocalConfigFiles(steamRoot: steamRoot)
        XCTAssertEqual(
            files.map(\.standardizedFileURL.path),
            [localConfig.standardizedFileURL.path]
        )
    }

    func testResolveWindowsPathFromUnixDrivePath() {
        let unixPath = "/Users/test/Library/Application Support/CrossOver/Bottles/steavium-steam/drive_c/Program Files (x86)/Steam/steamapps/common/Game/game.exe"
        let windowsPath = GameLibraryScanner.resolveWindowsPath(fromUnixPath: unixPath)
        XCTAssertEqual(windowsPath, "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Game\\game.exe")
    }
}
