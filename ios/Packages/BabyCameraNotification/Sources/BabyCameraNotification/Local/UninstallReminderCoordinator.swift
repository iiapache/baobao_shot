import Foundation
import UserNotifications

public struct UninstallReminderSchedulingResult: Sendable, Equatable {
    public var scheduled: Bool
    public var identifier: String?
    public var removedCount: Int

    public init(scheduled: Bool, identifier: String? = nil, removedCount: Int = 0) {
        self.scheduled = scheduled
        self.identifier = identifier
        self.removedCount = removedCount
    }
}

/// 卸载前备份提醒调度（design-ios §12.2 / T6.7）。
public struct UninstallReminderCoordinator: Sendable {
    public static let reminderIntervalDays = 7

    private let scheduler: any LocalNotificationScheduling
    private let preferencesStore: any UninstallReminderPreferencesStoring

    public init(
        scheduler: any LocalNotificationScheduling = LiveLocalNotificationScheduler(),
        preferencesStore: any UninstallReminderPreferencesStoring = UserDefaultsUninstallReminderStore()
    ) {
        self.scheduler = scheduler
        self.preferencesStore = preferencesStore
    }

    public func currentPreferences() -> UninstallReminderPreferences {
        preferencesStore.load()
    }

    @discardableResult
    public func updatePreferences(_ preferences: UninstallReminderPreferences) async throws -> UninstallReminderSchedulingResult {
        preferencesStore.save(preferences)
        return try await reschedule(using: preferences)
    }

    public func rescheduleStoredPreferences() async throws -> UninstallReminderSchedulingResult {
        try await reschedule(using: preferencesStore.load())
    }

    public func cancelAll() async -> Int {
        let pending = await scheduler.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter(UninstallReminderIdentifier.isUninstallReminder)
        await scheduler.removePendingNotificationRequests(withIdentifiers: identifiers)
        return identifiers.count
    }

    // MARK: - Private

    private func reschedule(using preferences: UninstallReminderPreferences) async throws -> UninstallReminderSchedulingResult {
        let removedCount = await cancelAll()
        guard preferences.enabled else {
            return UninstallReminderSchedulingResult(scheduled: false, removedCount: removedCount)
        }

        let identifier = UninstallReminderIdentifier.globalIdentifier()
        let request = makeNotificationRequest(identifier: identifier)
        try await scheduler.add(request)
        return UninstallReminderSchedulingResult(
            scheduled: true,
            identifier: identifier,
            removedCount: removedCount
        )
    }

    private func makeNotificationRequest(identifier: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "卸载前请先备份"
        content.body = "卸载 App 将删除本机原图与成长记录，请前往备份目标管理确认备份完成。"
        content.categoryIdentifier = UninstallReminderIdentifier.category
        content.sound = .default
        content.userInfo = UninstallReminderPayload.userInfo()

        let interval = TimeInterval(Self.reminderIntervalDays * 24 * 60 * 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)

        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
    }
}
