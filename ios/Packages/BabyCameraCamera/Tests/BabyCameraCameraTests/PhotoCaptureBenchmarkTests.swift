import XCTest
@testable import BabyCameraCamera

final class PhotoCaptureBenchmarkTests: XCTestCase {
    func testCaptureLatencyBudgetConstant() {
        XCTAssertEqual(PhotoCaptureBenchmark.captureLatencyBudgetMilliseconds, 200)
    }

    func testBurstTargetFPSConstant() {
        XCTAssertEqual(PhotoCaptureBenchmark.burstTargetFramesPerSecond, 10)
    }

    func testMeasurementWithinBudget() {
        let result = PhotoCaptureBenchmark.measure(latencySeconds: 0.15)
        XCTAssertEqual(result.latencyMilliseconds, 150)
        XCTAssertTrue(result.withinCaptureBudget)
    }

    func testMeasurementExceedsBudget() {
        let result = PhotoCaptureBenchmark.measure(latencySeconds: 0.25)
        XCTAssertEqual(result.latencyMilliseconds, 250)
        XCTAssertFalse(result.withinCaptureBudget)
    }

    func testBurstMeasurementMeetsTarget() {
        let result = PhotoCaptureBenchmark.measureBurst(frameCount: 10, durationSeconds: 0.9)
        XCTAssertGreaterThanOrEqual(result.framesPerSecond, 10)
        XCTAssertTrue(result.meetsTarget)
    }

    func testBurstMeasurementBelowTarget() {
        let result = PhotoCaptureBenchmark.measureBurst(frameCount: 5, durationSeconds: 1.0)
        XCTAssertEqual(result.framesPerSecond, 5)
        XCTAssertFalse(result.meetsTarget)
    }
}
