import Foundation
import UserNotifications

public struct MilestoneSchedulingRequest: Sendable, Equatable {
    public var babyId: String
    public var birthDate: String
    public var referenceDate: Date

    public init(babyId: String, birthDate: String, referenceDate: Date = Date()) {
        self.babyId = babyId
        self.birthDate = birthDate
        self.referenceDate = referenceDate
    }
}

public struct MilestoneSchedulingResult: Sendable, Equatable {
    public var scheduledCount: Int
    public var removedCount: Int
    public var identifiers: [String]

    public init(scheduledCount: Int, removedCount: Int, identifiers: [String]) {
        self.scheduledCount = scheduledCount
        self.removedCount = removedCount
        self.identifiers = identifiers
    }
}

/// 基于宝宝出生日预约未来 365 天内的里程碑本地通知（design-ios §10.2）。
public struct MilestoneScheduler: Sendable {
    public static let defaultNotificationHour = 9
    public static let defaultNotificationMinute = 0

    private let scheduler: any NotificationScheduling
    private let calendar: Calendar

    public init(
        scheduler: any NotificationScheduling = LiveNotificationScheduler(),
        calendar: Calendar = .current
    ) {
        self.scheduler = scheduler
        self.calendar = calendar
    }

    /// 为指定宝宝重新预约里程碑通知：先清理旧 identifier，再写入新请求。
    public func reschedule(for request: MilestoneSchedulingRequest) async throws -> MilestoneSchedulingResult {
        let occurrences = MilestoneDateCalculator.occurrences(
            milestones: MilestoneCatalog.milestones,
            birthDate: request.birthDate,
            babyId: request.babyId,
            referenceDate: request.referenceDate,
            calendar: calendar
        )

        let removedCount = try await removeExisting(for: request.babyId)

        var identifiers: [String] = []
        for occurrence in occurrences {
            let notificationRequest = makeNotificationRequest(
                occurrence: occurrence,
                babyId: request.babyId
            )
            try await scheduler.add(notificationRequest)
            identifiers.append(occurrence.notificationIdentifier)
        }

        return MilestoneSchedulingResult(
            scheduledCount: occurrences.count,
            removedCount: removedCount,
            identifiers: identifiers
        )
    }

    /// 取消指定宝宝的全部里程碑本地通知。
    public func cancelAll(for babyId: String) async throws -> Int {
        try await removeExisting(for: babyId)
    }

    // MARK: - Private

    private func removeExisting(for babyId: String) async throws -> Int {
        let prefix = MilestoneNotificationIdentifier.babyPrefix(babyId: babyId)
        let pending = await scheduler.pendingNotificationRequests()
        let toRemove = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        await scheduler.removePendingNotificationRequests(withIdentifiers: toRemove)
        return toRemove.count
    }

    private func makeNotificationRequest(
        occurrence: MilestoneDateCalculator.ScheduledOccurrence,
        babyId: String
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = occurrence.milestone.notificationTitle
        content.body = occurrence.milestone.notificationBody
        content.categoryIdentifier = MilestoneNotificationIdentifier.category
        content.userInfo = MilestoneNotificationPayload.userInfo(
            babyId: babyId,
            milestoneId: occurrence.milestone.id,
            templateId: occurrence.milestone.templateId,
            triggerDate: occurrence.triggerDate
        )

        var dateComponents = calendar.dateComponents(
            [.year, .month, .day],
            from: occurrence.triggerDate
        )
        dateComponents.hour = Self.defaultNotificationHour
        dateComponents.minute = Self.defaultNotificationMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        return UNNotificationRequest(
            identifier: occurrence.notificationIdentifier,
            content: content,
            trigger: trigger
        )
    }
}
