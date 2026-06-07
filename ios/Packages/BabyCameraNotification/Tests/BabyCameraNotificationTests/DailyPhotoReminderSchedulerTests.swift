import UserNotifications
import XCTest
@testable import BabyCameraNotification

final class DailyPhotoReminderSchedulerTests: XCTestCase {
    private var mockScheduler: MockLocalNotificationScheduler!
    private var mockStore: MockDailyPhotoReminderPreferencesStore!
    private var scheduler: DailyPhotoReminderScheduler!

    override func setUp() {
        super.setUp()
        mockScheduler = MockLocalNotificationScheduler()
        mockStore = MockDailyPhotoReminderPreferencesStore()
        scheduler = DailyPhotoReminderScheduler(
            scheduler: mockScheduler,
            preferencesStore: mockStore
        )
    }

    func testDisabledPreferencesRemovesExistingReminder() async throws {
        mockScheduler.pending = [
            UNNotificationRequest(
                identifier: DailyPhotoReminderIdentifier.make(babyId: "baby-1"),
                content: UNMutableNotificationContent(),
                trigger: nil
            ),
        ]

        let result = try await scheduler.updatePreferences(
            DailyPhotoReminderPreferences(enabled: false, babyId: "baby-1")
        )

        XCTAssertFalse(result.scheduled)
        XCTAssertEqual(result.removedCount, 1)
        XCTAssertTrue(mockScheduler.pending.isEmpty)
    }

    func testEnabledPreferencesSchedulesRepeatingDailyNotification() async throws {
        let result = try await scheduler.updatePreferences(
            DailyPhotoReminderPreferences(
                enabled: true,
                hour: 9,
                minute: 30,
                babyId: "baby-42",
                babyName: "小满"
            )
        )

        XCTAssertTrue(result.scheduled)
        XCTAssertEqual(result.identifier, "dailyPhoto.baby-42")
        XCTAssertEqual(mockScheduler.addedRequests.count, 1)

        let request = try XCTUnwrap(mockScheduler.addedRequests.first)
        XCTAssertEqual(request.content.title, "每日拍照提醒")
        XCTAssertEqual(request.content.body, "记录小满的成长瞬间吧")
        XCTAssertEqual(request.content.categoryIdentifier, DailyPhotoReminderIdentifier.category)

        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 9)
        XCTAssertEqual(trigger.dateComponents.minute, 30)
    }

    func testRescheduleStoredPreferencesUsesPersistedValues() async throws {
        mockStore.stored = DailyPhotoReminderPreferences(
            enabled: true,
            hour: 21,
            minute: 15,
            babyId: "baby-7"
        )

        let result = try await scheduler.rescheduleStoredPreferences()
        XCTAssertTrue(result.scheduled)
        let trigger = try XCTUnwrap(mockScheduler.addedRequests.first?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.hour, 21)
        XCTAssertEqual(trigger.dateComponents.minute, 15)
    }

    func testCancelAllRemovesOnlyDailyPhotoIdentifiers() async {
        mockScheduler.pending = [
            UNNotificationRequest(identifier: "dailyPhoto.baby-1", content: UNMutableNotificationContent(), trigger: nil),
            UNNotificationRequest(identifier: "milestone.baby-1.ms_full_moon", content: UNMutableNotificationContent(), trigger: nil),
        ]

        let removed = await scheduler.cancelAll()
        XCTAssertEqual(removed, 1)
        XCTAssertEqual(mockScheduler.removedIdentifiers, ["dailyPhoto.baby-1"])
    }
}
