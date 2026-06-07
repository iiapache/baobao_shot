import XCTest

/// XCUITest 公共辅助（T2.22 / NAV-10）。
enum XCUITestHelpers {
    private static let filterPickerValues = ["鲜明", "褪色", "即时", "黑白", "质感"]

    static func makeMainFlowApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITesting"]
        app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "1"
        return app
    }

    static func performLoginAndOnboarding(app: XCUIApplication) {
        let phoneField = app.textFields["loginPhoneField"]
        waitFor(phoneField)
        phoneField.tap()
        phoneField.typeText("13800138001")

        let codeField = app.textFields["loginCodeField"]
        codeField.tap()
        codeField.typeText("123456")

        tapWhenReady(app.buttons["loginPhoneSubmitButton"])

        let onboarding = app.otherElements["onboardingFlowView"]
        waitFor(onboarding)

        let nicknameField = app.textFields["onboardingNicknameField"]
        waitFor(nicknameField)
        nicknameField.tap()
        nicknameField.typeText("E2E用户")
        tapOnboardingNext(in: app)

        let familyNameField = app.textFields["onboardingFamilyNameField"]
        waitFor(familyNameField)
        familyNameField.tap()
        familyNameField.typeText("E2E家庭")
        tapOnboardingNext(in: app)

        let babyNameField = app.textFields["onboardingBabyNameField"]
        waitFor(babyNameField)
        babyNameField.tap()
        babyNameField.typeText("小测")
        tapOnboardingNext(in: app)

        let consentToggle = app.switches["onboardingConsentToggle"]
        if consentToggle.waitForExistence(timeout: 5) {
            consentToggle.tap()
        } else {
            app.buttons["我已阅读并同意《儿童信息监护人同意书》"].tap()
        }
        tapOnboardingNext(in: app)

        tapOnboardingNext(in: app, expectTitle: "开始使用")

        waitFor(app.otherElements["mainHomeView"])
        for tabId in ["mainTabCamera", "mainTabGrowth", "mainTabFeed", "mainTabAI", "mainTabProfile"] {
            XCTAssertTrue(app.otherElements[tabId].waitForExistence(timeout: 5), "Tab 标识缺失: \(tabId)")
        }
    }

    static func performCaptureEditSaveCycle(app: XCUIApplication, cycleIndex: Int) {
        tapMainTab(app, identifier: "mainTabCamera", fallbackTitle: "相机")
        waitFor(app.otherElements["mainTabCameraView"])
        waitFor(app.otherElements["mockCameraView"])
        tapWhenReady(app.buttons["mockCaptureButton"])

        waitFor(app.otherElements["mainTabEditorScreen"])
        waitFor(app.otherElements["photoEditorView"])

        let filterPicker = app.pickers["filterPicker"]
        if filterPicker.exists {
            filterPicker.adjust(toPickerWheelValue: filterPickerValues[cycleIndex % filterPickerValues.count])
        }

        tapWhenReady(app.buttons["applyFilterButton"])
        tapWhenReady(app.buttons["savePhotoButton"])

        waitFor(app.otherElements["mainTabGrowthScreen"])
        waitFor(app.otherElements["growthTimelineView"])
        XCTAssertTrue(
            app.otherElements.matching(
                NSPredicate(format: "identifier BEGINSWITH 'timelinePhoto-'")
            ).count > 0,
            "成长 Tab 应显示已保存照片"
        )
    }

    static func publishFeedPost(app: XCUIApplication, caption: String) {
        tapMainTab(app, identifier: "mainTabFeed", fallbackTitle: "家庭圈")
        waitFor(app.otherElements["mainTabFeedScreen"])
        waitFor(app.otherElements["feedListView"], timeout: 15)
        tapWhenReady(app.buttons["feedComposeButton"], timeout: 15)

        let captionField = app.textFields["发布文案"]
        if captionField.waitForExistence(timeout: 5) {
            captionField.tap()
            captionField.clearAndTypeText(caption)
        } else {
            let fallbackField = app.textFields.element(boundBy: 0)
            waitFor(fallbackField)
            fallbackField.tap()
            fallbackField.clearAndTypeText(caption)
        }

        tapWhenReady(app.buttons["feedPublishButton"])
        waitFor(app.otherElements["feedListView"])
    }

    static func verifyFeedContainsCaption(app: XCUIApplication, caption: String) {
        let captionLabel = app.staticTexts[caption]
        XCTAssertTrue(
            captionLabel.waitForExistence(timeout: 10),
            "Feed 列表应显示动态文案: \(caption)"
        )
    }

    static func makeP2E2EApp(offline: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITesting", "-P2E2E"]
        if offline {
            app.launchArguments += ["-OfflineMode"]
        }
        app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "1"
        return app
    }

    static func waitFor(_ element: XCUIElement, timeout: TimeInterval = 10) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "元素不存在: \(element.identifier)")
    }

    static func tapWhenReady(_ element: XCUIElement, timeout: TimeInterval = 10) {
        waitFor(element, timeout: timeout)
        XCTAssertTrue(element.isHittable, "元素不可点击: \(element.identifier)")
        element.tap()
    }

    static func performSingleCycle(app: XCUIApplication, cycleIndex: Int, expectedPhotoCount: Int) {
        tapWhenReady(app.buttons["mockCaptureButton"])

        waitFor(app.otherElements["photoEditorView"])

        let filterPicker = app.pickers["filterPicker"]
        if filterPicker.exists {
            filterPicker.adjust(toPickerWheelValue: filterPickerValues[cycleIndex % filterPickerValues.count])
        }

        tapWhenReady(app.buttons["applyFilterButton"])
        tapWhenReady(app.buttons["savePhotoButton"])

        waitFor(app.otherElements["p2e2eTimelineScreen"])

        let countLabel = app.staticTexts["timelinePhotoCountLabel"]
        waitFor(countLabel)
        XCTAssertTrue(countLabel.label.contains("\(expectedPhotoCount)"), "Timeline 照片计数应为 \(expectedPhotoCount)")

        tapLatestTimelinePhoto(in: app)

        waitFor(app.otherElements["photoEditorView"])
        tapWhenReady(app.buttons["applyFilterButton"])
        tapWhenReady(app.buttons["finishReEditButton"])

        waitFor(app.otherElements["mockCameraView"])

        let cyclesLabel = app.staticTexts["completedCyclesLabel"]
        waitFor(cyclesLabel)
        XCTAssertTrue(cyclesLabel.label.contains("\(cycleIndex)"), "应完成第 \(cycleIndex) 轮")
    }

    private static func tapLatestTimelinePhoto(in app: XCUIApplication) {
        let photoButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'timelinePhoto-photo_'")
        )
        if photoButtons.count > 0 {
            photoButtons.element(boundBy: 0).tap()
            return
        }

        let photoElements = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'timelinePhoto-photo_'")
        )
        waitFor(photoElements.element(boundBy: 0))
        photoElements.element(boundBy: 0).tap()
    }

    private static func tapOnboardingNext(in app: XCUIApplication, expectTitle: String = "下一步") {
        let button = app.buttons["onboardingPrimaryButton"]
        waitFor(button)
        if button.label.contains(expectTitle) || expectTitle == "下一步" {
            button.tap()
        }
    }

    private static func tapMainTab(
        app: XCUIApplication,
        identifier: String,
        fallbackTitle: String
    ) {
        XCTAssertTrue(
            app.otherElements[identifier].waitForExistence(timeout: 5),
            "Tab 标识应存在: \(identifier)"
        )
        tapWhenReady(app.tabBars.buttons[fallbackTitle])
    }
}

private extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        guard let stringValue = value as? String else {
            typeText(text)
            return
        }

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString + text)
    }
}
