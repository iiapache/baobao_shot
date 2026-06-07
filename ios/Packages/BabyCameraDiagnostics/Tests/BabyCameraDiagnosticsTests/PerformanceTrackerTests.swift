import XCTest
@testable import BabyCameraDiagnostics

final class PerformanceTrackerTests: XCTestCase {
    func testBudgetConstantsMatchDesignIOS() {
        XCTAssertEqual(PerformanceTracker.cameraColdStartBudgetMs, 800)
        XCTAssertEqual(PerformanceTracker.editorOpenBudgetMs, 500)
    }

    func testRecordCameraColdStartWithinBudget() {
        var trackedEvent: String?
        var trackedParams: [String: String] = [:]
        AnalyticsService.trackHandler = { event, params, _ in
            trackedEvent = event
            trackedParams = params
        }

        let measurement = PerformanceTracker.recordCameraColdStart(elapsedSeconds: 0.72, source: "test")

        XCTAssertEqual(measurement.name, "camera_cold_start")
        XCTAssertEqual(measurement.elapsedMilliseconds, 720)
        XCTAssertTrue(measurement.withinBudget)
        XCTAssertEqual(trackedEvent, AnalyticsEventCatalog.Camera.open)
        XCTAssertEqual(trackedParams["elapsedMs"], "720")
    }

    func testRecordCameraColdStartExceedsBudget() {
        let measurement = PerformanceTracker.recordCameraColdStart(elapsedSeconds: 0.95, source: "test")
        XCTAssertEqual(measurement.elapsedMilliseconds, 950)
        XCTAssertFalse(measurement.withinBudget)
        XCTAssertEqual(measurement.statusLabel, "FAIL")
    }

    func testRecordEditorOpenWithinBudget() {
        var trackedEvent: String?
        AnalyticsService.trackHandler = { event, _, _ in
            trackedEvent = event
        }

        let measurement = PerformanceTracker.recordEditorOpen(elapsedSeconds: 0.42, source: "camera")

        XCTAssertEqual(measurement.name, "editor_open")
        XCTAssertEqual(measurement.elapsedMilliseconds, 420)
        XCTAssertTrue(measurement.withinBudget)
        XCTAssertEqual(trackedEvent, AnalyticsEventCatalog.Editor.open)
    }

    func testFormattedLogLine() {
        let measurement = PerformanceTracker.Measurement(
            name: "camera_cold_start",
            elapsedMilliseconds: 650,
            budgetMilliseconds: 800
        )
        let line = PerformanceTracker.formattedLogLine(measurement, source: "camera_tab")
        XCTAssertTrue(line.contains("camera_cold_start"))
        XCTAssertTrue(line.contains("650ms"))
        XCTAssertTrue(line.contains("PASS"))
    }
}
