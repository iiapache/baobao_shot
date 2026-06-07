import XCTest

/// T2.22：拍照(mock) → 编辑(滤镜) → 保存 → Timeline → 重新编辑，5 次回归。
final class P2CaptureEditTimelineE2ETests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureEditSaveTimelineReeditFiveTimes() throws {
        let app = XCUITestHelpers.makeP2E2EApp()
        app.launch()

        XCUITestHelpers.waitFor(app.otherElements["p2e2eRootView"])
        XCUITestHelpers.waitFor(app.otherElements["mockCameraView"])

        for cycle in 1...5 {
            XCUITestHelpers.performSingleCycle(app: app, cycleIndex: cycle, expectedPhotoCount: cycle)
        }

        let cyclesLabel = app.staticTexts["completedCyclesLabel"]
        XCTAssertTrue(cyclesLabel.label.contains("5"), "5 轮回归应全部完成")
    }

    func testTimelineShowsSavedPhotosAfterEachSave() throws {
        let app = XCUITestHelpers.makeP2E2EApp()
        app.launch()

        XCUITestHelpers.tapWhenReady(app.buttons["mockCaptureButton"])
        XCUITestHelpers.tapWhenReady(app.buttons["applyFilterButton"])
        XCUITestHelpers.tapWhenReady(app.buttons["savePhotoButton"])

        XCUITestHelpers.waitFor(app.otherElements["growthTimelineView"])
        XCUITestHelpers.waitFor(app.staticTexts["timelinePhotoCountLabel"])
    }
}
