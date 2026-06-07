import UserNotifications
import XCTest
@testable import BabyCameraMilestone

final class MockNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private(set) var pending: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [String] = []
    private(set) var addedRequests: [UNNotificationRequest] = []
    var addError: Error?

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pending
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async {
        removedIdentifiers.append(contentsOf: identifiers)
        pending.removeAll { identifiers.contains($0.identifier) }
    }

    func add(_ request: UNNotificationRequest) async throws {
        if let addError { throw addError }
        addedRequests.append(request)
        pending.append(request)
    }
}

final class MilestoneSchedulerTests: XCTestCase {
    private var mock: MockNotificationScheduler!
    private var scheduler: MilestoneScheduler!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        mock = MockNotificationScheduler()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        calendar = cal
        scheduler = MilestoneScheduler(scheduler: mock, calendar: calendar)
    }

    func testRescheduleAddsNotificationsWithin365Days() async throws {
        let request = MilestoneSchedulingRequest(
            babyId: "baby-42",
            birthDate: "2025-06-01",
            referenceDate: makeDate(year: 2025, month: 6, day: 1)
        )
        let result = try await scheduler.reschedule(for: request)

        XCTAssertGreaterThan(result.scheduledCount, 0)
        XCTAssertEqual(result.scheduledCount, mock.addedRequests.count)
        XCTAssertEqual(Set(result.identifiers), Set(mock.addedRequests.map(\.identifier)))

        for notification in mock.addedRequests {
            XCTAssertTrue(MilestoneNotificationIdentifier.isMilestoneNotification(notification.identifier))
            XCTAssertTrue(notification.identifier.hasPrefix("milestone.baby-42."))
            XCTAssertEqual(notification.content.categoryIdentifier, MilestoneNotificationIdentifier.category)
            XCTAssertNotNil(notification.content.userInfo[MilestoneNotificationPayload.deepLinkKey])
        }
    }

    func testRescheduleRemovesExistingBeforeAdding() async throws {
        let existing = UNNotificationRequest(
            identifier: "milestone.baby-42.ms_full_moon",
            content: UNMutableNotificationContent(),
            trigger: nil
        )
        mock.pending = [existing]

        let request = MilestoneSchedulingRequest(
            babyId: "baby-42",
            birthDate: "2025-06-01",
            referenceDate: makeDate(year: 2025, month: 6, day: 1)
        )
        let result = try await scheduler.reschedule(for: request)

        XCTAssertEqual(result.removedCount, 1)
        XCTAssertTrue(mock.removedIdentifiers.contains("milestone.baby-42.ms_full_moon"))
    }

    func testRescheduleDeduplicatesIdentifiers() async throws {
        let request = MilestoneSchedulingRequest(
            babyId: "baby-42",
            birthDate: "2025-01-01",
            referenceDate: makeDate(year: 2024, month: 12, day: 1)
        )
        let result = try await scheduler.reschedule(for: request)

        let unique = Set(result.identifiers)
        XCTAssertEqual(unique.count, result.identifiers.count)
    }

    func testCancelAllRemovesBabyNotifications() async throws {
        mock.pending = [
            UNNotificationRequest(identifier: "milestone.baby-42.ms_full_moon", content: UNMutableNotificationContent(), trigger: nil),
            UNNotificationRequest(identifier: "milestone.baby-99.ms_full_moon", content: UNMutableNotificationContent(), trigger: nil),
            UNNotificationRequest(identifier: "other.notification", content: UNMutableNotificationContent(), trigger: nil),
        ]

        let removed = try await scheduler.cancelAll(for: "baby-42")
        XCTAssertEqual(removed, 1)
        XCTAssertEqual(mock.removedIdentifiers, ["milestone.baby-42.ms_full_moon"])
    }

    func testNotificationTriggerUsesDefaultMorningTime() async throws {
        let request = MilestoneSchedulingRequest(
            babyId: "baby-42",
            birthDate: "2025-06-01",
            referenceDate: makeDate(year: 2025, month: 6, day: 1)
        )
        _ = try await scheduler.reschedule(for: request)

        guard let first = mock.addedRequests.first,
              let trigger = first.trigger as? UNCalendarNotificationTrigger else {
            XCTFail("缺少日历触发器")
            return
        }
        XCTAssertEqual(trigger.dateComponents.hour, MilestoneScheduler.defaultNotificationHour)
        XCTAssertEqual(trigger.dateComponents.minute, MilestoneScheduler.defaultNotificationMinute)
        XCTAssertFalse(trigger.repeats)
    }

    func testRescheduleRespects365DayCap() async throws {
        let request = MilestoneSchedulingRequest(
            babyId: "baby-42",
            birthDate: "2025-01-01",
            referenceDate: makeDate(year: 2025, month: 1, day: 1)
        )
        let result = try await scheduler.reschedule(for: request)
        let referenceStart = calendar.startOfDay(for: request.referenceDate)
        let horizon = calendar.date(byAdding: .day, value: 365, to: referenceStart)!

        for notification in mock.addedRequests {
            guard let trigger = notification.trigger as? UNCalendarNotificationTrigger,
                  let triggerDate = calendar.date(from: trigger.dateComponents) else {
                continue
            }
            XCTAssertLessThanOrEqual(calendar.startOfDay(for: triggerDate), horizon)
        }
        XCTAssertGreaterThan(result.scheduledCount, 0)
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)!
    }
}
