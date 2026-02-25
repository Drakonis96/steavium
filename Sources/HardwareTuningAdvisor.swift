import Foundation

enum HardwareTuningAdvisor {
    static func recommendedBackend(
        chipFamily: AppleChipFamily,
        performanceTier: PerformanceTier,
        memoryGB: Int
    ) -> GraphicsBackend {
        switch chipFamily {
        case .m1, .m2, .appleSiliconOther:
            return .d3dmetal
        case .m3, .m4:
            if performanceTier == .extreme && memoryGB >= 24 {
                return .dxvk
            }
            return .d3dmetal
        case .m5:
            // M5 has 3rd-gen ray tracing and ~7.4 TFLOPS GPU; DXVK
            // benefits from its 153 GB/s bandwidth at extreme/performance tiers.
            if performanceTier == .extreme && memoryGB >= 16 {
                return .dxvk
            }
            if performanceTier == .performance && memoryGB >= 24 {
                return .dxvk
            }
            return .d3dmetal
        case .intel, .unknown:
            return .dxvk
        }
    }

    static func recommendedFPSCap(
        performanceTier: PerformanceTier,
        displayRefreshRate: Int = 60
    ) -> Int? {
        let baseCap: Int
        switch performanceTier {
        case .economy:
            baseCap = 45
        case .balanced:
            baseCap = 60
        case .performance:
            // On high-refresh displays (≥90 Hz), allow 90 FPS.
            baseCap = displayRefreshRate >= 90 ? 90 : 75
        case .extreme:
            // On ProMotion (120 Hz) displays, unlock to 120 FPS.
            baseCap = displayRefreshRate >= 120 ? 120 : 90
        }
        // Never exceed the display refresh rate.
        return min(baseCap, max(displayRefreshRate, 30))
    }

    static func recommendedDXVKCompilerThreads(
        performanceTier: PerformanceTier,
        memoryGB: Int,
        coreLayout: CPUCoreLayout
    ) -> Int {
        let profileTarget: Int
        switch performanceTier {
        case .economy:
            profileTarget = 2
        case .balanced:
            profileTarget = 3
        case .performance:
            profileTarget = 5
        case .extreme:
            profileTarget = 6
        }

        var maxAllowed = 8

        if coreLayout.performanceCores > 0 {
            // When efficiency cores are present (≥2), they absorb system
            // overhead — all P-cores can drive DXVK compilation. This
            // applies to every Apple Silicon generation (M1–M5). Without
            // E-cores (Intel / unknown), reserve one P-core for the OS.
            let performanceBudget: Int
            if coreLayout.efficiencyCores >= 2 {
                performanceBudget = coreLayout.performanceCores
            } else {
                performanceBudget = coreLayout.performanceCores - 1
            }
            maxAllowed = min(maxAllowed, max(2, performanceBudget))
        }
        if coreLayout.logicalCores > 0 {
            maxAllowed = min(maxAllowed, max(2, coreLayout.logicalCores / 2))
        }

        let memoryBound: Int
        switch memoryGB {
        case ..<9:
            memoryBound = 3
        case ..<13:
            memoryBound = 4
        case ..<17:
            memoryBound = 6
        default:
            memoryBound = 8
        }
        maxAllowed = min(maxAllowed, memoryBound)

        return max(2, min(profileTarget, maxAllowed))
    }
}
