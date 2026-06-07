import XCTest
@testable import BabyCameraMilestone

final class MilestoneNotificationHandlerTests: XCTestCase {
    func testDestinationFromUserInfo() throws {
        let userInfo = MilestoneNotificationPayload.userInfo(
            babyId: "baby-1",
            milestoneId: "ms_hundred_days",
            templateId: "tpl_hundred_01",
            triggerDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let destination = try MilestoneNotificationHandler.destination(from: userInfo)

        XCTAssertEqual(destination.babyId, "baby-1")
        XCTAssertEqual(destination.milestoneId, "ms_hundred_days")
        XCTAssertEqual(destination.milestoneName, "百天")
        XCTAssertEqual(destination.templateId, "tpl_hundred_01")
        XCTAssertNotNil(destination.templateStep)
        XCTAssertEqual(destination.templateStep?.templateID, "tpl_hundred_01")
    }

    func testDestinationFromDeepLink() throws {
        let url = URL(string: "baobao://milestone?babyId=baby-1&milestoneId=ms_full_moon&templateId=tpl_growth_03")!
        let destination = try MilestoneNotificationHandler.destination(from: url)

        XCTAssertEqual(destination.babyId, "baby-1")
        XCTAssertEqual(destination.milestoneId, "ms_full_moon")
        XCTAssertEqual(destination.milestoneName, "满月")
        XCTAssertEqual(destination.templateId, "tpl_growth_03")
        XCTAssertNotNil(destination.templateStep)
    }

    func testDestinationResolvesTemplateFromCatalogWhenOmittedInPayload() throws {
        let userInfo = MilestoneNotificationPayload.userInfo(
            babyId: "baby-2",
            milestoneId: "ms_first_birthday",
            templateId: nil,
            triggerDate: Date()
        )
        let destination = try MilestoneNotificationHandler.destination(from: userInfo)
        XCTAssertEqual(destination.templateId, "tpl_birthday_01")
        XCTAssertEqual(destination.templateStep?.templateID, "tpl_birthday_01")
    }

    func testInvalidPayloadThrows() {
        XCTAssertThrowsError(try MilestoneNotificationHandler.destination(from: [:])) { error in
            XCTAssertEqual(error as? MilestoneNotificationHandler.Error, .invalidPayload)
        }
    }

    func testDeepLinkRoundTrip() {
        let payload = MilestoneNotificationPayload(
            babyId: "baby-1",
            milestoneId: "ms_hundred_days",
            templateId: "tpl_hundred_01"
        )
        let url = payload.deepLinkURL!
        let parsed = MilestoneNotificationPayload.from(deepLink: url)
        XCTAssertEqual(parsed, payload)
    }

    func testMakeTemplateStepForKnownTemplate() throws {
        let step = try MilestoneNotificationHandler.makeTemplateStep(templateId: "tpl_growth_01")
        XCTAssertEqual(step.templateID, "tpl_growth_01")
    }

    func testMakeTemplateStepUnknownTemplateThrows() {
        XCTAssertThrowsError(try MilestoneNotificationHandler.makeTemplateStep(templateId: "unknown_tpl")) { error in
            XCTAssertEqual(error as? MilestoneNotificationHandler.Error, .templateNotFound("unknown_tpl"))
        }
    }
}
