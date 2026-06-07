import XCTest
@testable import BabyCameraCamera

/// T2.5 性能基准占位；真机专项见 T7.6 / tests/performance/device-matrix.md。
final class CameraStartupBenchmarkTests: XCTestCase {
    func testBudgetConstantMatchesDesign() {
        XCTAssertEqual(CameraStartupBenchmark.budgetMilliseconds, 800)
    }

    func testMeasurementWithinBudget() {
        let result = CameraStartupBenchmark.measure(elapsedSeconds: 0.65)
        XCTAssertEqual(result.elapsedMilliseconds, 650)
        XCTAssertTrue(result.withinBudget)
    }

    func testMeasurementExceedsBudget() {
        let result = CameraStartupBenchmark.measure(elapsedSeconds: 0.95)
        XCTAssertEqual(result.elapsedMilliseconds, 950)
        XCTAssertFalse(result.withinBudget)
    }

    func testEnvironmentGateSkipsSimulator() {
        XCTAssertFalse(
            CameraStartupBenchmark.shouldRunOnCurrentEnvironment(
                isSimulator: true,
                hasCameraHardware: true
            )
        )
    }

    func testEnvironmentGateRequiresHardware() {
        XCTAssertFalse(
            CameraStartupBenchmark.shouldRunOnCurrentEnvironment(
                isSimulator: false,
                hasCameraHardware: false
            )
        )
    }

    /// 真机基准占位：在 LAB-IP12-001 上取消 skip 并记录 Instruments 结果。
    func testCameraColdStartOnDevice_placeholder() throws {
        let shouldRun = CameraStartupBenchmark.shouldRunOnCurrentEnvironment(
            isSimulator: ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil,
            hasCameraHardware: true
        )
        try XCTSkipUnless(
            shouldRun,
            "相机冷启动基准需在真机 iPhone 12+ 执行（T7.6）；当前环境跳过。"
        )

        // 占位：集成测试应测量 viewWillAppear → 首帧预览 耗时并断言 ≤ 800ms。
        let simulatedElapsed = CameraStartupBenchmark.measure(elapsedSeconds: 0.72)
        XCTAssertTrue(
            simulatedElapsed.withinBudget,
            "相机启动 \(simulatedElapsed.elapsedMilliseconds)ms 超过预算 \(CameraStartupBenchmark.budgetMilliseconds)ms"
        )
    }
}
