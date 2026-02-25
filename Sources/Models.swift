import Foundation

enum GraphicsBackend: String, CaseIterable, Sendable {
    case d3dmetal
    case dxvk
    case auto

    func title(in language: AppLanguage) -> String {
        switch self {
        case .d3dmetal:
            return "D3DMetal"
        case .dxvk:
            return "DXVK"
        case .auto:
            return "Auto"
        }
    }

    var title: String {
        title(in: .english)
    }
}

// MARK: - Launch Phase

enum LaunchPhase: Sendable, Equatable {
    case preparingEnvironment
    case spawningProcess
    case waitingForSteam(elapsedSeconds: Int)
    case steamProcessStarted(elapsedSeconds: Int)
    case steamDetected

    func title(in language: AppLanguage) -> String {
        switch self {
        case .preparingEnvironment:
            return L.launchPhasePreparing.resolve(in: language)
        case .spawningProcess:
            return L.launchPhaseSpawning.resolve(in: language)
        case .waitingForSteam(let elapsed):
            return L.launchPhaseWaiting(elapsed).resolve(in: language)
        case .steamProcessStarted(let elapsed):
            return L.launchPhaseProcessStarted(elapsed).resolve(in: language)
        case .steamDetected:
            return L.launchPhaseSteamDetected.resolve(in: language)
        }
    }

    /// Estimated progress 0…1 for the progress bar.
    var estimatedProgress: Double {
        switch self {
        case .preparingEnvironment:
            return 0.1
        case .spawningProcess:
            return 0.25
        case .waitingForSteam(let elapsed):
            // Asymptotic approach to 0.65 over ~30s
            let t = Double(elapsed)
            return 0.25 + 0.40 * (1.0 - exp(-t / 12.0))
        case .steamProcessStarted(let elapsed):
            // Process exists but window not yet visible; 0.65 → 0.95
            let t = Double(elapsed)
            return 0.65 + 0.30 * (1.0 - exp(-t / 15.0))
        case .steamDetected:
            return 1.0
        }
    }
}

enum SteamRunningPolicy: String, CaseIterable, Sendable {
    case askEveryTime = "ask"
    case reuseExisting = "reuse"
    case restart = "restart"

    func title(in language: AppLanguage) -> String {
        switch self {
        case .askEveryTime:
            return L.ask.resolve(in: language)
        case .reuseExisting:
            return L.reuse.resolve(in: language)
        case .restart:
            return L.restart.resolve(in: language)
        }
    }

    var title: String {
        title(in: .english)
    }
}

enum AppleChipFamily: String, Sendable {
    case m1
    case m2
    case m3
    case m4
    case m5
    case appleSiliconOther
    case intel
    case unknown

    func title(in language: AppLanguage) -> String {
        switch self {
        case .m1:
            return "Apple M1"
        case .m2:
            return "Apple M2"
        case .m3:
            return "Apple M3"
        case .m4:
            return "Apple M4"
        case .m5:
            return "Apple M5"
        case .appleSiliconOther:
            return "Apple Silicon"
        case .intel:
            return "Intel"
        case .unknown:
            return L.unknown.resolve(in: language)
        }
    }

    var title: String {
        title(in: .english)
    }
}

enum PerformanceTier: String, Sendable {
    case economy
    case balanced
    case performance
    case extreme

    func title(in language: AppLanguage) -> String {
        switch self {
        case .economy:
            return L.economy.resolve(in: language)
        case .balanced:
            return L.balanced.resolve(in: language)
        case .performance:
            return L.performance.resolve(in: language)
        case .extreme:
            return L.extreme.resolve(in: language)
        }
    }

    var title: String {
        title(in: .english)
    }
}

struct CPUCoreLayout: Sendable, Equatable {
    let performanceCores: Int
    let efficiencyCores: Int
    let logicalCores: Int

    static let unknown = CPUCoreLayout(
        performanceCores: 0,
        efficiencyCores: 0,
        logicalCores: 0
    )

    var summary: String {
        if performanceCores > 0 && efficiencyCores > 0 {
            return "P\(performanceCores) / E\(efficiencyCores) (\(logicalCores) logical)"
        }
        if performanceCores > 0 {
            return "\(performanceCores) cores (\(logicalCores) logical)"
        }
        if logicalCores > 0 {
            return "\(logicalCores) logical"
        }
        return "Not detected"
    }

    func summary(in language: AppLanguage) -> String {
        if performanceCores > 0 && efficiencyCores > 0 {
            return L.cpuLayoutPE(performanceCores, efficiencyCores, logicalCores).resolve(in: language)
        }
        if performanceCores > 0 {
            return L.cpuLayoutCores(performanceCores, logicalCores).resolve(in: language)
        }
        if logicalCores > 0 {
            return L.cpuLayoutLogical(logicalCores).resolve(in: language)
        }
        return L.notDetected.resolve(in: language)
    }
}

struct HardwareProfile: Sendable {
    let chipModel: String
    let chipFamily: AppleChipFamily
    let memoryGB: Int
    let cpuCoreLayout: CPUCoreLayout
    let performanceTier: PerformanceTier
    let recommendedBackend: GraphicsBackend
    let recommendedDXVKCompilerThreads: Int
    let recommendedFPSCap: Int?
    let displayRefreshRate: Int
    let displayResolutionIdentifier: String

    static let empty = HardwareProfile(
        chipModel: "Unknown",
        chipFamily: .unknown,
        memoryGB: 0,
        cpuCoreLayout: .unknown,
        performanceTier: .balanced,
        recommendedBackend: .d3dmetal,
        recommendedDXVKCompilerThreads: 3,
        recommendedFPSCap: nil,
        displayRefreshRate: 60,
        displayResolutionIdentifier: "Not detected"
    )
}

struct SteamEnvironment: Sendable {
    let appHomePath: String
    let prefixPath: String
    let logsPath: String
    let wine64Path: String?
    let steamInstalled: Bool
    let steamExecutablePath: String?
    let hardwareProfile: HardwareProfile

    static let empty = SteamEnvironment(
        appHomePath: "",
        prefixPath: "",
        logsPath: "",
        wine64Path: nil,
        steamInstalled: false,
        steamExecutablePath: nil,
        hardwareProfile: .empty
    )
}

enum GamepadSource: String, Sendable {
    case gameController = "GameController"
    case hid = "HID"
}

struct GamepadDeviceInfo: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let source: GamepadSource
    let vendorID: Int?
    let productID: Int?
}

struct GameExecutableCandidate: Identifiable, Sendable, Hashable {
    let relativePath: String
    let absolutePath: String
    let score: Int

    var id: String { relativePath.lowercased() }
}

struct InstalledGame: Identifiable, Sendable, Hashable {
    let appID: Int
    let name: String
    let installDirectoryPath: String
    let executableCandidates: [GameExecutableCandidate]
    let defaultExecutableRelativePath: String?

    var id: Int { appID }
}

enum GameCompatibilityPreset: String, CaseIterable, Codable, Sendable {
    case automatic
    case legacyVideoSafe
    case windowedSafe
    case custom

    func title(in language: AppLanguage) -> String {
        switch self {
        case .automatic:
            return L.presetNoChanges.resolve(in: language)
        case .legacyVideoSafe:
            return L.presetClassicMode.resolve(in: language)
        case .windowedSafe:
            return L.presetWindowedSafe.resolve(in: language)
        case .custom:
            return L.presetCustom.resolve(in: language)
        }
    }

    var title: String {
        title(in: .english)
    }
}

enum GameCompatibilityMode: String, CaseIterable, Codable, Sendable {
    case none
    case windows95
    case windows98Me
    case windowsXPServicePack2
    case windowsXPServicePack3
    case windowsVistaServicePack2
    case windows7
    case windows8

    func title(in language: AppLanguage) -> String {
        switch self {
        case .none:
            return L.disabled.resolve(in: language)
        case .windows95:
            return "Windows 95"
        case .windows98Me:
            return "Windows 98 / ME"
        case .windowsXPServicePack2:
            return "Windows XP (SP2)"
        case .windowsXPServicePack3:
            return "Windows XP (SP3)"
        case .windowsVistaServicePack2:
            return "Windows Vista (SP2)"
        case .windows7:
            return "Windows 7"
        case .windows8:
            return "Windows 8"
        }
    }

    var title: String {
        title(in: .english)
    }

    var compatibilityLayerFlag: String? {
        switch self {
        case .none:
            return nil
        case .windows95:
            return "WIN95"
        case .windows98Me:
            return "WIN98"
        case .windowsXPServicePack2:
            return "WINXPSP2"
        case .windowsXPServicePack3:
            return "WINXPSP3"
        case .windowsVistaServicePack2:
            return "VISTASP2"
        case .windows7:
            return "WIN7RTM"
        case .windows8:
            return "WIN8RTM"
        }
    }
}

enum GameReducedColorMode: String, CaseIterable, Codable, Sendable {
    case none
    case colors256
    case colors16Bit

    func title(in language: AppLanguage) -> String {
        switch self {
        case .none:
            return L.disabled.resolve(in: language)
        case .colors256:
            return L.colors256.resolve(in: language)
        case .colors16Bit:
            return L.colors16Bit.resolve(in: language)
        }
    }

    var title: String {
        title(in: .english)
    }

    var compatibilityLayerFlag: String? {
        switch self {
        case .none:
            return nil
        case .colors256:
            return "256COLOR"
        case .colors16Bit:
            return "16BITCOLOR"
        }
    }
}

enum GameHighDPIOverrideMode: String, CaseIterable, Codable, Sendable {
    case none
    case application

    func title(in language: AppLanguage) -> String {
        switch self {
        case .none:
            return L.disabled.resolve(in: language)
        case .application:
            return L.application.resolve(in: language)
        }
    }

    var title: String {
        title(in: .english)
    }

    var compatibilityLayerFlags: [String] {
        switch self {
        case .none:
            return []
        case .application:
            return ["HIGHDPIAWARE"]
        }
    }
}

struct GameCompatibilityProfile: Codable, Sendable, Hashable {
    let appID: Int
    var preset: GameCompatibilityPreset
    var executableRelativePath: String?
    var compatibilityMode: GameCompatibilityMode
    var forceWindowed: Bool
    var force640x480: Bool
    var reducedColorMode: GameReducedColorMode
    var highDPIOverrideMode: GameHighDPIOverrideMode
    var disableFullscreenOptimizations: Bool
    var runAsAdmin: Bool

    private enum CodingKeys: String, CodingKey {
        case appID
        case preset
        case executableRelativePath
        case compatibilityMode
        case forceWindowed
        case force640x480
        case reducedColorMode
        case highDPIOverrideMode
        case force16BitColor
        case disableFullscreenOptimizations
        case runAsAdmin
    }

    init(
        appID: Int,
        preset: GameCompatibilityPreset,
        executableRelativePath: String?,
        compatibilityMode: GameCompatibilityMode,
        forceWindowed: Bool,
        force640x480: Bool,
        reducedColorMode: GameReducedColorMode,
        highDPIOverrideMode: GameHighDPIOverrideMode,
        disableFullscreenOptimizations: Bool,
        runAsAdmin: Bool
    ) {
        self.appID = appID
        self.preset = preset
        self.executableRelativePath = executableRelativePath
        self.compatibilityMode = compatibilityMode
        self.forceWindowed = forceWindowed
        self.force640x480 = force640x480
        self.reducedColorMode = reducedColorMode
        self.highDPIOverrideMode = highDPIOverrideMode
        self.disableFullscreenOptimizations = disableFullscreenOptimizations
        self.runAsAdmin = runAsAdmin
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appID = try container.decode(Int.self, forKey: .appID)
        preset = try container.decodeIfPresent(GameCompatibilityPreset.self, forKey: .preset) ?? .automatic
        executableRelativePath = try container.decodeIfPresent(String.self, forKey: .executableRelativePath)
        compatibilityMode = (try? container.decode(GameCompatibilityMode.self, forKey: .compatibilityMode)) ?? .none
        forceWindowed = try container.decodeIfPresent(Bool.self, forKey: .forceWindowed) ?? false
        force640x480 = try container.decodeIfPresent(Bool.self, forKey: .force640x480) ?? false

        if let decodedColorMode = try? container.decode(GameReducedColorMode.self, forKey: .reducedColorMode) {
            reducedColorMode = decodedColorMode
        } else if try container.decodeIfPresent(Bool.self, forKey: .force16BitColor) == true {
            // Backward compatibility with profile schema v1.
            reducedColorMode = .colors16Bit
        } else {
            reducedColorMode = .none
        }

        highDPIOverrideMode = (try? container.decode(GameHighDPIOverrideMode.self, forKey: .highDPIOverrideMode)) ?? .none
        disableFullscreenOptimizations = try container.decodeIfPresent(Bool.self, forKey: .disableFullscreenOptimizations) ?? false
        runAsAdmin = try container.decodeIfPresent(Bool.self, forKey: .runAsAdmin) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appID, forKey: .appID)
        try container.encode(preset, forKey: .preset)
        try container.encodeIfPresent(executableRelativePath, forKey: .executableRelativePath)
        try container.encode(compatibilityMode, forKey: .compatibilityMode)
        try container.encode(forceWindowed, forKey: .forceWindowed)
        try container.encode(force640x480, forKey: .force640x480)
        try container.encode(reducedColorMode, forKey: .reducedColorMode)
        try container.encode(highDPIOverrideMode, forKey: .highDPIOverrideMode)
        try container.encode(disableFullscreenOptimizations, forKey: .disableFullscreenOptimizations)
        try container.encode(runAsAdmin, forKey: .runAsAdmin)
    }

    static func defaults(appID: Int, defaultExecutableRelativePath: String?) -> GameCompatibilityProfile {
        GameCompatibilityProfile(
            appID: appID,
            preset: .automatic,
            executableRelativePath: defaultExecutableRelativePath,
            compatibilityMode: .none,
            forceWindowed: false,
            force640x480: false,
            reducedColorMode: .none,
            highDPIOverrideMode: .none,
            disableFullscreenOptimizations: false,
            runAsAdmin: false
        )
    }

    mutating func applyPreset(_ preset: GameCompatibilityPreset) {
        self.preset = preset
        switch preset {
        case .automatic:
            compatibilityMode = .none
            forceWindowed = false
            force640x480 = false
            reducedColorMode = .none
            highDPIOverrideMode = .none
            disableFullscreenOptimizations = false
            runAsAdmin = false
        case .legacyVideoSafe:
            compatibilityMode = .none
            forceWindowed = false
            force640x480 = true
            reducedColorMode = .colors16Bit
            highDPIOverrideMode = .none
            disableFullscreenOptimizations = true
            runAsAdmin = false
        case .windowedSafe:
            compatibilityMode = .none
            forceWindowed = true
            force640x480 = false
            reducedColorMode = .none
            highDPIOverrideMode = .none
            disableFullscreenOptimizations = true
            runAsAdmin = false
        case .custom:
            break
        }
    }

    mutating func refreshPresetFromFlags() {
        let automatic = compatibilityMode == .none && !forceWindowed && !force640x480 && reducedColorMode == .none &&
            highDPIOverrideMode == .none &&
            !disableFullscreenOptimizations && !runAsAdmin
        if automatic {
            preset = .automatic
            return
        }

        if compatibilityMode == .none && !forceWindowed && force640x480 && reducedColorMode == .colors16Bit &&
            highDPIOverrideMode == .none &&
            disableFullscreenOptimizations && !runAsAdmin {
            preset = .legacyVideoSafe
            return
        }

        if compatibilityMode == .none && forceWindowed && !force640x480 && reducedColorMode == .none &&
            highDPIOverrideMode == .none &&
            disableFullscreenOptimizations && !runAsAdmin {
            preset = .windowedSafe
            return
        }

        preset = .custom
    }

    var hasOverrides: Bool {
        compatibilityMode != .none || forceWindowed || force640x480 || reducedColorMode != .none ||
            highDPIOverrideMode != .none ||
            disableFullscreenOptimizations || runAsAdmin
    }

    var compatibilityLayerFlags: [String] {
        var flags: [String] = []
        if let compatibilityModeFlag = compatibilityMode.compatibilityLayerFlag {
            flags.append(compatibilityModeFlag)
        }
        if force640x480 {
            flags.append("640X480")
        }
        if let reducedColorModeFlag = reducedColorMode.compatibilityLayerFlag {
            flags.append(reducedColorModeFlag)
        }
        flags.append(contentsOf: highDPIOverrideMode.compatibilityLayerFlags)
        if disableFullscreenOptimizations {
            flags.append("DISABLEDXMAXIMIZEDWINDOWEDMODE")
        }
        if runAsAdmin {
            flags.append("RUNASADMIN")
        }
        return flags
    }
}

struct GameProfileEditorState: Sendable {
    var appID: Int?
    var preset: GameCompatibilityPreset
    var selectedExecutableRelativePath: String
    var compatibilityMode: GameCompatibilityMode
    var forceWindowed: Bool
    var force640x480: Bool
    var reducedColorMode: GameReducedColorMode
    var highDPIOverrideMode: GameHighDPIOverrideMode
    var disableFullscreenOptimizations: Bool
    var runAsAdmin: Bool

    init(
        appID: Int?,
        preset: GameCompatibilityPreset,
        selectedExecutableRelativePath: String,
        compatibilityMode: GameCompatibilityMode,
        forceWindowed: Bool,
        force640x480: Bool,
        reducedColorMode: GameReducedColorMode,
        highDPIOverrideMode: GameHighDPIOverrideMode,
        disableFullscreenOptimizations: Bool,
        runAsAdmin: Bool
    ) {
        self.appID = appID
        self.preset = preset
        self.selectedExecutableRelativePath = selectedExecutableRelativePath
        self.compatibilityMode = compatibilityMode
        self.forceWindowed = forceWindowed
        self.force640x480 = force640x480
        self.reducedColorMode = reducedColorMode
        self.highDPIOverrideMode = highDPIOverrideMode
        self.disableFullscreenOptimizations = disableFullscreenOptimizations
        self.runAsAdmin = runAsAdmin
    }

    static let empty = GameProfileEditorState(
        appID: nil,
        preset: .automatic,
        selectedExecutableRelativePath: "",
        compatibilityMode: .none,
        forceWindowed: false,
        force640x480: false,
        reducedColorMode: .none,
        highDPIOverrideMode: .none,
        disableFullscreenOptimizations: false,
        runAsAdmin: false
    )

    init(game: InstalledGame, profile: GameCompatibilityProfile?) {
        let resolvedProfile = profile ?? .defaults(appID: game.appID, defaultExecutableRelativePath: game.defaultExecutableRelativePath)
        appID = game.appID
        preset = resolvedProfile.preset
        selectedExecutableRelativePath = resolvedProfile.executableRelativePath ?? ""
        compatibilityMode = resolvedProfile.compatibilityMode
        forceWindowed = resolvedProfile.forceWindowed
        force640x480 = resolvedProfile.force640x480
        reducedColorMode = resolvedProfile.reducedColorMode
        highDPIOverrideMode = resolvedProfile.highDPIOverrideMode
        disableFullscreenOptimizations = resolvedProfile.disableFullscreenOptimizations
        runAsAdmin = resolvedProfile.runAsAdmin
    }

    func makeProfile() -> GameCompatibilityProfile? {
        guard let appID else { return nil }
        return GameCompatibilityProfile(
            appID: appID,
            preset: preset,
            executableRelativePath: selectedExecutableRelativePath.isEmpty ? nil : selectedExecutableRelativePath,
            compatibilityMode: compatibilityMode,
            forceWindowed: forceWindowed,
            force640x480: force640x480,
            reducedColorMode: reducedColorMode,
            highDPIOverrideMode: highDPIOverrideMode,
            disableFullscreenOptimizations: disableFullscreenOptimizations,
            runAsAdmin: runAsAdmin
        )
    }
}

struct GameLibraryState: Sendable {
    let games: [InstalledGame]
    let profiles: [GameCompatibilityProfile]

    static let empty = GameLibraryState(games: [], profiles: [])
}
