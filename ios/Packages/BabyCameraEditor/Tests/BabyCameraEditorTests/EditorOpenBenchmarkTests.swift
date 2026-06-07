import XCTest
@testable import BabyCameraEditor

/// T7.6 编辑器打开性能基准占位；真机专项见 tests/performance/。
final class EditorOpenBenchmarkTests: XCTestCase {
    func testBudgetConstantMatchesDesign() {
        XCTAssertEqual(EditorOpenBenchmark.budgetMilliseconds, 500)
    }

    func testMeasurementWithinBudget() {
        let result = EditorOpenBenchmark.measure(elapsedSeconds: 0.42)
        XCTAssertEqual(result.elapsedMilliseconds, 420)
        XCTAssertTrue(result.withinBudget)
    }

    func testMeasurementExceedsBudget() {
        let result = EditorOpenBenchmark.measure(elapsedSeconds: 0.65)
        XCTAssertEqual(result.elapsedMilliseconds, 650)
        XCTAssertFalse(result.withinBudget)
    }

    func testEnvironmentGateSkipsSimulator() {
        XCTAssertFalse(EditorOpenBenchmark.shouldRunOnCurrentEnvironment(isSimulator: true))
    }

    /// 真机基准占位：在 LAB-IP12-001 上取消 skip 并记录埋点 `editor_open_ms`。
    func testEditorOpenOnDevice_placeholder() throws {
        let isSimulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        try XCTSkipUnless(
            EditorOpenBenchmark.shouldRunOnCurrentEnvironment(isSimulator: isSimulator),
            "编辑器打开基准需在真机 iPhone 12+ 执行（T7.6）；当前环境跳过。"
        )

        let simulatedElapsed = EditorOpenBenchmark.measure(elapsedSeconds: 0.38)
        XCTAssertTrue(
            simulatedElapsed.withinBudget,
            "编辑器打开 \(simulatedElapsed.elapsedMilliseconds)ms 超过预算 \(EditorOpenBenchmark.budgetMilliseconds)ms"
        )
    }
}
