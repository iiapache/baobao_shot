import XCTest

/// T6.15 · Widget 四形态 + 设置导出/备份 + 注销入口 smoke（-P6E2E mock）
final class P6BackupWidgetSettingsE2ETests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITesting", "-P6E2E"]
        app.launch()
    }

    func testWidgetKindsSettingsExportBackupAndDeleteAccountSmoke() throws {
        let root = app.otherElements["p6e2eRootView"]
        XCTAssertTrue(root.waitForExistence(timeout: 10))

        XCTAssertTrue(app.otherElements["widgetSmokeSmall"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["widgetSmokeMedium"].exists)
        XCTAssertTrue(app.otherElements["widgetSmokeLarge"].exists)
        XCTAssertTrue(app.otherElements["widgetSmokeLockScreen"].exists)

        app.buttons["p6SettingsSmokeLink"].tap()
        XCTAssertTrue(app.otherElements["settingsRootView"].waitForExistence(timeout: 5))

        app.buttons["dataExportLink"].tap()
        XCTAssertTrue(app.otherElements["dataExportView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["dataExportStartButton"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["dataBackupTargetsLink"].tap()
        XCTAssertTrue(app.otherElements["backupTargetsManagementView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["backupTarget_iCloud"].exists)
        XCTAssertTrue(app.otherElements["backupTarget_baiduPan"].exists)
        XCTAssertTrue(app.otherElements["backupTarget_photos"].exists)
        XCTAssertTrue(app.otherElements["backupStatusSummary"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["settingsAccountLink"].tap()
        app.buttons["deleteAccountLink"].tap()

        let deleteButton = app.buttons["confirmDeleteAccountButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        let confirmDelete = app.buttons["注销账号"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 3))
        confirmDelete.tap()

        let successAlert = app.alerts["注销已提交"]
        XCTAssertTrue(successAlert.waitForExistence(timeout: 5))
        successAlert.buttons["知道了"].tap()
    }
}
