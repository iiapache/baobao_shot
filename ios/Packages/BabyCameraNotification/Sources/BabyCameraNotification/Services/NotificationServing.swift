import BabyCameraNetwork
import Foundation

public enum NotificationServiceError: Error, Equatable, Sendable {
    case notAuthenticated
    case categoryLocked(NotificationCategoryCode)
}

public protocol NotificationServing: AnyObject, Sendable {
    var unreadCount: Int { get }

    func refreshUnreadCount() async throws
    func listNotifications(cursor: String?) async throws -> NotificationListData
    func markAllRead() async throws -> MarkNotificationsReadData
    func loadCategorySubscriptions() async throws -> [NotificationCategory]
    func updateCategory(_ category: NotificationCategoryCode, enabled: Bool) async throws -> [NotificationCategory]
}
