import XCTest

/// T7.16 · 可访问性 smoke：关键视图 `accessibilityIdentifier` 存在性检查。
/// VoiceOver / Dynamic Type / 对比度 / 深色模式需人工填写 `docs/qa/A11Y_REGRESSION_REPORT_TEMPLATE.md`。
final class AccessibilitySmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Login (-UITesting)

    func testLoginAccessibilityIdentifiersExist() throws {
        app.launchArguments += ["-UITesting"]
        app.launch()

        XCTAssertTrue(
            app.otherElements["loginView"].waitForExistence(timeout: 10),
            "loginView"
        )
        XCTAssertTrue(app.textFields["loginPhoneField"].exists, "loginPhoneField")
        XCTAssertTrue(app.textFields["loginCodeField"].exists, "loginCodeField")
        XCTAssertTrue(app.buttons["loginAppleButton"].exists, "loginAppleButton")
        XCTAssertTrue(app.buttons["loginSendCodeButton"].exists, "loginSendCodeButton")
        XCTAssertTrue(app.buttons["loginPhoneSubmitButton"].exists, "loginPhoneSubmitButton")
    }

    // MARK: - Settings (-P6E2E)

    func testSettingsAccessibilityIdentifiersExist() throws {
        app.launchArguments += ["-UITesting", "-P6E2E"]
        app.launch()

        XCTAssertTrue(app.otherElements["p6e2eRootView"].waitForExistence(timeout: 10))
        app.buttons["p6SettingsSmokeLink"].tap()

        let settingsRoot = app.otherElements["settingsRootView"]
        XCTAssertTrue(settingsRoot.waitForExistence(timeout: 5), "settingsRootView")
        XCTAssertTrue(app.buttons["settingsAccountLink"].exists, "settingsAccountLink")
        XCTAssertTrue(app.buttons["dataExportLink"].exists, "dataExportLink")
        XCTAssertTrue(app.buttons["dataBackupTargetsLink"].exists, "dataBackupTargetsLink")
    }

    // MARK: - Camera mock (-P2E2E)

    func testCameraMockAccessibilityIdentifiersExist() throws {
        app.launchArguments += ["-UITesting", "-P2E2E"]
        app.launch()

        let cameraView = app.otherElements["mockCameraView"]
        XCTAssertTrue(cameraView.waitForExistence(timeout: 10), "mockCameraView")
        XCTAssertTrue(app.otherElements["mockCameraPreview"].exists, "mockCameraPreview")
        XCTAssertTrue(app.buttons["mockCaptureButton"].exists, "mockCaptureButton")
        XCTAssertTrue(app.buttons["openTimelineButton"].exists, "openTimelineButton")
    }
}
