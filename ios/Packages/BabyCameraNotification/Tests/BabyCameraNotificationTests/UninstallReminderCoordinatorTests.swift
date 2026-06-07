import UserNotifications
import XCTest
@testable import BabyCameraNotification

final class UninstallReminderCoordinatorTests: XCTestCase {
    private var mockScheduler: MockLocalNotificationScheduler!
    private var mockStore: MockUninstallReminderPreferencesStore!
    private var coordinator: UninstallReminderCoordinator!

    override func setUp() {
        super.setUp()
        mockScheduler = MockLocalNotificationScheduler()
        mockStore = MockUninstallReminderPreferencesStore()
        coordinator = UninstallReminderCoordinator(
            scheduler: mockScheduler,
            preferencesStore: mockStore
        )
    }

    func testDisabledPreferencesRemovesExistingReminder() async throws {
        mockScheduler.pending = [
            UNNotificationRequest(
                identifier: UninstallReminderIdentifier.globalIdentifier(),
                content: UNMutableNotificationContent(),
                trigger: nil
            ),
        ]

        let result = try await coordinator.updatePreferences(
            UninstallReminderPreferences(enabled: false)
        )

        XCTAssertFalse(result.scheduled)
        XCTAssertEqual(result.removedCount, 1)
        XCTAssertTrue(mockScheduler.pending.isEmpty)
        XCTAssertEqual(mockStore.saved?.enabled, false)
    }

    func testEnabledPreferencesSchedulesRepeatingSevenDayNotification() async throws {
        let result = try await coordinator.updatePreferences(
            UninstallReminderPreferences(enabled: true)
        )

        XCTAssertTrue(result.scheduled)
        XCTAssertEqual(result.identifier, UninstallReminderIdentifier.globalIdentifier())
        XCTAssertEqual(mockScheduler.addedRequests.count, 1)

        let request = try XCTUnwrap(mockScheduler.addedRequests.first)
        XCTAssertEqual(request.content.title, "卸载前请先备份")
        XCTAssertEqual(request.content.categoryIdentifier, UninstallReminderIdentifier.category)

        let trigger = try XCTUnwrap(request.trigger as? UNTimeIntervalNotificationTrigger)
        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.timeInterval, TimeInterval(UninstallReminderCoordinator.reminderIntervalDays * 24 * 60 * 60))
    }

    func testNotificationUserInfoContainsBackupRoute() async throws {
        _ = try await coordinator.updatePreferences(UninstallReminderPreferences(enabled: true))

        let request = try XCTUnwrap(mockScheduler.addedRequests.first)
        XCTAssertEqual(request.content.userInfo[UninstallReminderPayload.sourceKey] as? String, "uninstallReminder")
        XCTAssertEqual(request.content.userInfo[UninstallReminderPayload.routeKey] as? String, "backup")
        XCTAssertEqual(
            request.content.userInfo[UninstallReminderPayload.deepLinkKey] as? String,
            "baobao://settings/backup"
        )
        XCTAssertNotNil(UninstallReminderPayload.from(userInfo: request.content.userInfo))
    }

    func testCancelAllRemovesOnlyUninstallReminderIdentifiers() async {
        mockScheduler.pending = [
            UNNotificationRequest(
                identifier: UninstallReminderIdentifier.globalIdentifier(),
                content: UNMutableNotificationContent(),
                trigger: nil
            ),
            UNNotificationRequest(
                identifier: "dailyPhoto.baby-1",
                content: UNMutableNotificationContent(),
                trigger: nil
            ),
        ]

        let removed = await coordinator.cancelAll()
        XCTAssertEqual(removed, 1)
        XCTAssertEqual(mockScheduler.removedIdentifiers, [UninstallReminderIdentifier.globalIdentifier()])
    }
}
