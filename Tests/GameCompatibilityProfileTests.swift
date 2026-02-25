import XCTest
@testable import Steavium

final class GameCompatibilityProfileTests: XCTestCase {
    func testCompatibilityLayerFlagsIncludesModeAndColor() {
        let profile = GameCompatibilityProfile(
            appID: 220,
            preset: .custom,
            executableRelativePath: "hl2.exe",
            compatibilityMode: .windows7,
            forceWindowed: false,
            force640x480: true,
            reducedColorMode: .colors256,
            highDPIOverrideMode: .none,
            disableFullscreenOptimizations: true,
            runAsAdmin: true
        )

        XCTAssertEqual(
            profile.compatibilityLayerFlags,
            ["WIN7RTM", "640X480", "256COLOR", "DISABLEDXMAXIMIZEDWINDOWEDMODE", "RUNASADMIN"]
        )
    }

    func testRefreshPresetFromFlagsKeepsCustomWhenCompatibilityModeEnabled() {
        var profile = GameCompatibilityProfile(
            appID: 220,
            preset: .legacyVideoSafe,
            executableRelativePath: "hl2.exe",
            compatibilityMode: .windowsXPServicePack3,
            forceWindowed: false,
            force640x480: true,
            reducedColorMode: .colors16Bit,
            highDPIOverrideMode: .none,
            disableFullscreenOptimizations: true,
            runAsAdmin: false
        )

        profile.refreshPresetFromFlags()
        XCTAssertEqual(profile.preset, .custom)
    }

    func testCompatibilityLayerFlagsIncludeXPServicePack2AndHighDPIOverride() {
        let profile = GameCompatibilityProfile(
            appID: 752580,
            preset: .custom,
            executableRelativePath: "gbr.exe",
            compatibilityMode: .windowsXPServicePack2,
            forceWindowed: false,
            force640x480: false,
            reducedColorMode: .none,
            highDPIOverrideMode: .application,
            disableFullscreenOptimizations: false,
            runAsAdmin: false
        )

        XCTAssertEqual(profile.compatibilityLayerFlags, ["WINXPSP2", "HIGHDPIAWARE"])
    }
}
