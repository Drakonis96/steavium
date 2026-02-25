import XCTest
@testable import Steavium

final class HardwareTuningAdvisorTests: XCTestCase {

    // MARK: - Recommended Backend

    func testRecommendedBackendPrefersD3DMetalOnM1() {
        let backend = HardwareTuningAdvisor.recommendedBackend(
            chipFamily: .m1,
            performanceTier: .balanced,
            memoryGB: 16
        )

        XCTAssertEqual(backend, .d3dmetal)
    }

    func testRecommendedBackendPrefersD3DMetalOnM2() {
        let backend = HardwareTuningAdvisor.recommendedBackend(
            chipFamily: .m2,
            performanceTier: .performance,
            memoryGB: 24
        )

        XCTAssertEqual(backend, .d3dmetal)
    }

    func testRecommendedBackendUsesDXVKOnExtremeM4() {
        let backend = HardwareTuningAdvisor.recommendedBackend(
            chipFamily: .m4,
            performanceTier: .extreme,
            memoryGB: 32
        )

        XCTAssertEqual(backend, .dxvk)
    }

    func testRecommendedBackendPrefersD3DMetalOnM4PerformanceTier() {
        let backend = HardwareTuningAdvisor.recommendedBackend(
            chipFamily: .m4,
            performanceTier: .performance,
            memoryGB: 16
        )

        XCTAssertEqual(backend, .d3dmetal)
    }

    func testRecommendedBackendUsesDXVKOnExtremeM5With16GB() {
        let backend = HardwareTuningAdvisor.recommendedBackend(
            chipFamily: .m5,
            performanceTier: .extreme,
            memoryGB: 16
        )

        XCTAssertEqual(backend, .dxvk)
    }

    func testRecommendedBackendUsesDXVKOnPerformanceM5With24GB() {
        let backend = HardwareTuningAdvisor.recommendedBackend(
            chipFamily: .m5,
            performanceTier: .performance,
            memoryGB: 24
        )

        XCTAssertEqual(backend, .dxvk)
    }

    func testRecommendedBackendPrefersD3DMetalOnPerformanceM5With16GB() {
        let backend = HardwareTuningAdvisor.recommendedBackend(
            chipFamily: .m5,
            performanceTier: .performance,
            memoryGB: 16
        )

        XCTAssertEqual(backend, .d3dmetal)
    }

    func testRecommendedBackendPrefersD3DMetalOnBalancedM5() {
        let backend = HardwareTuningAdvisor.recommendedBackend(
            chipFamily: .m5,
            performanceTier: .balanced,
            memoryGB: 8
        )

        XCTAssertEqual(backend, .d3dmetal)
    }

    // MARK: - DXVK Compiler Threads

    func testRecommendedCompilerThreadsUsesAllPCoresWithECores() {
        // M2-like layout: 4P + 4E. With ≥2 E-cores the budget is all
        // P-cores (4), so performance tier target (5) is clamped to 4.
        let threads = HardwareTuningAdvisor.recommendedDXVKCompilerThreads(
            performanceTier: .performance,
            memoryGB: 16,
            coreLayout: CPUCoreLayout(
                performanceCores: 4,
                efficiencyCores: 4,
                logicalCores: 8
            )
        )

        XCTAssertEqual(threads, 4)
    }

    func testRecommendedCompilerThreadsReservesPCoreWithoutECores() {
        // Intel-like layout: 8P + 0E. Without E-cores the budget is
        // performanceCores-1 = 7, logical half = 4 → maxAllowed = 4.
        // Performance target = 5, clamped to 4.
        let threads = HardwareTuningAdvisor.recommendedDXVKCompilerThreads(
            performanceTier: .performance,
            memoryGB: 16,
            coreLayout: CPUCoreLayout(
                performanceCores: 8,
                efficiencyCores: 0,
                logicalCores: 8
            )
        )

        XCTAssertEqual(threads, 4)
    }

    func testRecommendedCompilerThreadsM1ProLayout() {
        // M1 Pro-like: 8P + 2E. With ≥2 E-cores the budget is all
        // 8 P-cores, logical half = 5, memory bound(16) = 6 → 5.
        // Extreme target = 6, clamped to 5.
        let threads = HardwareTuningAdvisor.recommendedDXVKCompilerThreads(
            performanceTier: .extreme,
            memoryGB: 16,
            coreLayout: CPUCoreLayout(
                performanceCores: 8,
                efficiencyCores: 2,
                logicalCores: 10
            )
        )

        XCTAssertEqual(threads, 5)
    }

    func testRecommendedCompilerThreadsRespectsMemoryBudget() {
        let threads = HardwareTuningAdvisor.recommendedDXVKCompilerThreads(
            performanceTier: .performance,
            memoryGB: 8,
            coreLayout: CPUCoreLayout(
                performanceCores: 8,
                efficiencyCores: 2,
                logicalCores: 10
            )
        )

        XCTAssertEqual(threads, 3)
    }

    func testRecommendedCompilerThreadsHasSafeMinimum() {
        let threads = HardwareTuningAdvisor.recommendedDXVKCompilerThreads(
            performanceTier: .economy,
            memoryGB: 4,
            coreLayout: CPUCoreLayout(
                performanceCores: 1,
                efficiencyCores: 0,
                logicalCores: 1
            )
        )

        XCTAssertEqual(threads, 2)
    }
}
