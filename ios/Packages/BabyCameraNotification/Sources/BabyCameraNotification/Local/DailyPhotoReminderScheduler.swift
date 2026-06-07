import Foundation
import UserNotifications

public struct DailyPhotoReminderSchedulingResult: Sendable, Equatable {
    public var scheduled: Bool
    public var identifier: String?
    public var removedCount: Int

    public init(scheduled: Bool, identifier: String? = nil, removedCount: Int = 0) {
        self.scheduled = scheduled
        self.identifier = identifier
        self.removedCount = removedCount
    }
}

/// 每日拍照本地提醒调度（design-ios §10.2 / PRD §4.12）。
public struct DailyPhotoReminderScheduler: Sendable {
    private let scheduler: any LocalNotificationScheduling
    private let preferencesStore: any DailyPhotoReminderPreferencesStoring
    private let calendar: Calendar

    public init(
        scheduler: any LocalNotificationScheduling = LiveLocalNotificationScheduler(),
        preferencesStore: any DailyPhotoReminderPreferencesStoring = UserDefaultsDailyPhotoReminderStore(),
        calendar: Calendar = .current
    ) {
        self.scheduler = scheduler
        self.preferencesStore = preferencesStore
        self.calendar = calendar
    }

    public func currentPreferences() -> DailyPhotoReminderPreferences {
        preferencesStore.load()
    }

    @discardableResult
    public func updatePreferences(_ preferences: DailyPhotoReminderPreferences) async throws -> DailyPhotoReminderSchedulingResult {
        preferencesStore.save(preferences)
        return try await reschedule(using: preferences)
    }

    public func rescheduleStoredPreferences() async throws -> DailyPhotoReminderSchedulingResult {
        try await reschedule(using: preferencesStore.load())
    }

    public func cancelAll() async -> Int {
        let pending = await scheduler.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter(DailyPhotoReminderIdentifier.isDailyPhotoReminder)
        await scheduler.removePendingNotificationRequests(withIdentifiers: identifiers)
        return identifiers.count
    }

    // MARK: - Private

    private func reschedule(using preferences: DailyPhotoReminderPreferences) async throws -> DailyPhotoReminderSchedulingResult {
        let removedCount = await cancelAll()
        guard preferences.enabled else {
            return DailyPhotoReminderSchedulingResult(scheduled: false, removedCount: removedCount)
        }

        let identifier = notificationIdentifier(for: preferences)
        let request = makeNotificationRequest(preferences: preferences, identifier: identifier)
        try await scheduler.add(request)
        return DailyPhotoReminderSchedulingResult(
            scheduled: true,
            identifier: identifier,
            removedCount: removedCount
        )
    }

    private func notificationIdentifier(for preferences: DailyPhotoReminderPreferences) -> String {
        if let babyId = preferences.babyId, !babyId.isEmpty {
            return DailyPhotoReminderIdentifier.make(babyId: babyId)
        }
        return DailyPhotoReminderIdentifier.globalIdentifier()
    }

    private func makeNotificationRequest(
        preferences: DailyPhotoReminderPreferences,
        identifier: String
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "每日拍照提醒"
        if let babyName = preferences.babyName, !babyName.isEmpty {
            content.body = "记录\(babyName)的成长瞬间吧"
        } else {
            content.body = "今天还没有给宝宝拍照，快去记录成长瞬间吧"
        }
        content.categoryIdentifier = DailyPhotoReminderIdentifier.category
        content.sound = .default
        var userInfo: [AnyHashable: Any] = [
            "source": "dailyPhotoReminder",
        ]
        if let babyId = preferences.babyId {
            userInfo["babyId"] = babyId
        }
        content.userInfo = userInfo

        var dateComponents = DateComponents()
        dateComponents.hour = preferences.normalizedHour
        dateComponents.minute = preferences.normalizedMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
    }
}
