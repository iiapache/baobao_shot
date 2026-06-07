import XCTest

/// NAV-10 · 主 App 端到端：登录 → 引导 → Mock 拍照 → 编辑保存 → 成长 Tab → 家庭圈发布 → Feed 列表。
/// 启动参数仅 `-UITesting`（走 `UITestBootstrap` + `MockURLProtocol.uitestMainAppHandler`）。
final class MainFlowE2ETests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUITestHelpers.makeMainFlowApp()
    }

    func testMainFlowLoginCapturePublishFeedOnce() throws {
        app.launch()
        XCUITestHelpers.performLoginAndOnboarding(app: app)
        XCUITestHelpers.performCaptureEditSaveCycle(app: app, cycleIndex: 1)
        let caption = "E2E主流程动态1"
        XCUITestHelpers.publishFeedPost(app: app, caption: caption)
        XCUITestHelpers.verifyFeedContainsCaption(app: app, caption: caption)
    }

    func testMainFlowLoginCapturePublishFeedThreeTimes() throws {
        app.launch()
        XCUITestHelpers.performLoginAndOnboarding(app: app)

        for cycle in 1...3 {
            XCUITestHelpers.performCaptureEditSaveCycle(app: app, cycleIndex: cycle)
            let caption = "E2E主流程动态\(cycle)"
            XCUITestHelpers.publishFeedPost(app: app, caption: caption)
            XCUITestHelpers.verifyFeedContainsCaption(app: app, caption: caption)
        }
    }
}
