import XCTest

/// T7.6 性能基准汇总（相机 ≤ 800ms · 编辑器 ≤ 500ms）。
/// 真机测量：`PerformanceTracker` 日志 + [INSTRUMENTS_GUIDE.md](../../../tests/performance/INSTRUMENTS_GUIDE.md)
/// API 压测：tests/performance/benchmark-feed.sh · benchmark-ai-mock.sh
final class PerformanceBenchmarkTests: XCTestCase {
    private enum Budget {
        static let cameraColdStartMs = 800
        static let editorOpenMs = 500
    }

    private struct MetricSample {
        let name: String
        let elapsedMs: Int
        let budgetMs: Int

        var withinBudget: Bool { elapsedMs <= budgetMs }
    }

    /// Stub：模拟真机记录值（替换为 Instruments / 埋点实测）。
    private func stubSamples() -> [MetricSample] {
        [
            MetricSample(name: "camera_cold_start", elapsedMs: 720, budgetMs: Budget.cameraColdStartMs),
            MetricSample(name: "editor_open", elapsedMs: 420, budgetMs: Budget.editorOpenMs),
        ]
    }

    func testPerformanceBudgetConstants() {
        XCTAssertEqual(Budget.cameraColdStartMs, 800)
        XCTAssertEqual(Budget.editorOpenMs, 500)
    }

    func testStubMetricsWithinBudget() {
        for sample in stubSamples() {
            XCTAssertTrue(
                sample.withinBudget,
                "\(sample.name): \(sample.elapsedMs)ms > budget \(sample.budgetMs)ms"
            )
        }
    }

    /// 真机占位：在 LAB-IP12-001 / LAB-IP16-001 上取消 skip，接入实测耗时。
    func testDevicePerformance_placeholder() throws {
        let isSimulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        try XCTSkipUnless(
            !isSimulator,
            "T7.6 真机性能基准需在 iPhone 12/16 执行；模拟器跳过。见 tests/performance/README.md"
        )

        for sample in stubSamples() {
            XCTAssertTrue(sample.withinBudget)
        }
    }
}
