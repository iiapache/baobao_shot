import Foundation

/// 未读红点计数；进入消息中心后清零（design-ios §10.3）。
@MainActor
public final class UnreadBadgeStore: ObservableObject {
    @Published public private(set) var unreadCount: Int = 0

    public let notificationService: any NotificationServing

    public init(notificationService: any NotificationServing) {
        self.notificationService = notificationService
    }

    public var showsBadge: Bool { unreadCount > 0 }

    public func refresh() async {
        do {
            try await notificationService.refreshUnreadCount()
            unreadCount = notificationService.unreadCount
        } catch {
            // 静默失败，保留上次计数
        }
    }

    public func syncFromServerCount(_ count: Int) {
        unreadCount = max(0, count)
    }

    public func clear() {
        unreadCount = 0
    }
}
