import XCTest

/// T1.20 · 登录 → 创建家庭 → 创建宝宝 → 注销（mock API）
/// 邀请家人双用户场景见 tests/e2e/e2e.sh / Postman 集合
final class P1AccountFamilyE2ETests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-UITesting")
        app.launch()
    }

    func testLoginOnboardingCreateFamilyBabyAndDeleteAccount() throws {
        let phoneField = app.textFields["loginPhoneField"]
        XCTAssertTrue(phoneField.waitForExistence(timeout: 10))
        phoneField.tap()
        phoneField.typeText("13800138001")

        let codeField = app.textFields["loginCodeField"]
        codeField.tap()
        codeField.typeText("123456")

        app.buttons["loginPhoneSubmitButton"].tap()

        let onboarding = app.otherElements["onboardingFlowView"]
        XCTAssertTrue(onboarding.waitForExistence(timeout: 10))

        // Step 1: 昵称
        let nicknameField = app.textFields["onboardingNicknameField"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: 5))
        nicknameField.tap()
        nicknameField.typeText("E2E用户")
        tapOnboardingNext()

        // Step 2: 创建家庭
        let familyNameField = app.textFields["onboardingFamilyNameField"]
        XCTAssertTrue(familyNameField.waitForExistence(timeout: 5))
        familyNameField.tap()
        familyNameField.typeText("E2E家庭")
        tapOnboardingNext()

        // Step 3: 宝宝
        let babyNameField = app.textFields["onboardingBabyNameField"]
        XCTAssertTrue(babyNameField.waitForExistence(timeout: 5))
        babyNameField.tap()
        babyNameField.typeText("小测")
        tapOnboardingNext()

        // Step 4: 监护人同意
        let consentToggle = app.switches["onboardingConsentToggle"]
        if consentToggle.waitForExistence(timeout: 5) {
            consentToggle.tap()
        } else {
            app.buttons["我已阅读并同意《儿童信息监护人同意书》"].tap()
        }
        tapOnboardingNext()

        // Step 5: 备份引导 → 完成
        tapOnboardingNext(expectTitle: "开始使用")

        let home = app.otherElements["mainHomeView"]
        XCTAssertTrue(home.waitForExistence(timeout: 10))

        // 账号入口已迁移至「我的」Tab
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.otherElements["mainTabProfile"].waitForExistence(timeout: 5))

        // 注销账号
        app.buttons["accountSettingsLink"].tap()
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

        // 应回到登录页
        XCTAssertTrue(app.textFields["loginPhoneField"].waitForExistence(timeout: 10))
    }

    private func tapOnboardingNext(expectTitle: String = "下一步") {
        let button = app.buttons["onboardingPrimaryButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        if button.label.contains(expectTitle) || expectTitle == "下一步" {
            button.tap()
        }
    }
}
