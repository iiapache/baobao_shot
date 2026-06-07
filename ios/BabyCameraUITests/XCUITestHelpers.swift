import XCTest

/// XCUITest 公共辅助（T2.22）。
enum XCUITestHelpers {
    private static let filterPickerValues = ["鲜明", "褪色", "即时", "黑白", "质感"]

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
}
