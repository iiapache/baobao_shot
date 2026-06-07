import Foundation
import UserNotifications

// MARK: - Injectable scheduling

public protocol NotificationScheduling: Sendable {
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async
    func add(_ request: UNNotificationRequest) async throws
}

public struct LiveNotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    public func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    public func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }
}
