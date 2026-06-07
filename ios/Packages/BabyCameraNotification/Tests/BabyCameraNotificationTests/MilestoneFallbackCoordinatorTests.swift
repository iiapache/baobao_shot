import UserNotifications
import XCTest
@testable import BabyCameraMilestone
@testable import BabyCameraNotification

final class MilestoneFallbackCoordinatorTests: XCTestCase {
    private var mockScheduler: MockLocalNotificationScheduler!
    private var coordinator: MilestoneFallbackCoordinator!

    override func setUp() {
        super.setUp()
        mockScheduler = MockLocalNotificationScheduler()
        coordinator = MilestoneFallbackCoordinator(scheduler: mockScheduler)
    }

    func testRemovesMatchingLocalMilestoneNotification() async {
        mockScheduler.pending = [
            UNNotificationRequest(
                identifier: MilestoneNotificationIdentifier.make(babyId: "baby-42", milestoneId: "ms_full_moon"),
                content: UNMutableNotificationContent(),
                trigger: nil
            ),
            UNNotificationRequest(
                identifier: MilestoneNotificationIdentifier.make(babyId: "baby-42", milestoneId: "ms_100_days"),
                content: UNMutableNotificationContent(),
                trigger: nil
            ),
        ]

        let result = await coordinator.handleRemoteFallback(userInfo: [
            "category": "MILESTONE",
            "babyId": "baby-42",
            "milestoneId": "ms_full_moon",
            "aps": ["alert": ["title": "里程碑提醒"]],
        ])

        XCTAssertEqual(result.removedLocalNotificationIdentifiers, [
            MilestoneNotificationIdentifier.make(babyId: "baby-42", milestoneId: "ms_full_moon"),
        ])
        XCTAssertEqual(result.babyId, "baby-42")
        XCTAssertEqual(result.milestoneId, "ms_full_moon")
        XCTAssertEqual(mockScheduler.removedIdentifiers.count, 1)
    }

    func testIgnoresNonMilestonePush() async {
        let result = await coordinator.handleRemoteFallback(userInfo: [
            "category": "AI_DONE",
            "taskId": "tsk_001",
            "aps": ["content-available": 1],
        ])

        XCTAssertTrue(result.removedLocalNotificationIdentifiers.isEmpty)
        XCTAssertNil(result.babyId)
    }

    func testParsesMilestonePayloadFromDeepLinkUserInfo() async {
        let userInfo = MilestoneNotificationPayload.userInfo(
            babyId: "baby-99",
            milestoneId: "ms_100_days",
            templateId: "tpl_100",
            triggerDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let result = await coordinator.handleRemoteFallback(userInfo: userInfo.merging([
            "category": "MILESTONE",
            "aps": ["alert": ["title": "里程碑提醒"]],
        ]) { _, new in new })

        XCTAssertEqual(result.babyId, "baby-99")
        XCTAssertEqual(result.milestoneId, "ms_100_days")
    }
}
