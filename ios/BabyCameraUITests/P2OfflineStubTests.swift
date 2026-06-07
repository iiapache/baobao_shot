import XCTest

/// T2.22 离线场景 stub：全程本地 mock，不依赖网络与真机相机。
final class P2OfflineStubTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOfflineModeFullCycleStub() throws {
        let app = XCUITestHelpers.makeP2E2EApp(offline: true)
        app.launch()

        XCUITestHelpers.waitFor(app.otherElements["mockCameraView"])
        XCUITestHelpers.waitFor(app.staticTexts["offlineStatusLabel"])

        XCUITestHelpers.performSingleCycle(app: app, cycleIndex: 1, expectedPhotoCount: 1)

        let status = app.staticTexts["p2e2eStatusLabel"]
        XCTAssertTrue(status.label.contains("离线") || status.label.contains("完成"), "离线流程应正常完成")
    }

    func testOfflineModeTimelineAccessibleWithoutNetwork() throws {
        let app = XCUITestHelpers.makeP2E2EApp(offline: true)
        app.launch()

        XCUITestHelpers.tapWhenReady(app.buttons["openTimelineButton"])
        XCUITestHelpers.waitFor(app.otherElements["p2e2eTimelineScreen"])
        XCUITestHelpers.waitFor(app.otherElements["growthTimelineView"])
    }
}
