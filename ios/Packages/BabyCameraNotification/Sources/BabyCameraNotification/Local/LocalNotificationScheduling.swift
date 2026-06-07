import Foundation
import UserNotifications

/// 可注入的本地通知调度，便于单测（design-ios §10.2）。
public protocol LocalNotificationScheduling: Sendable {
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async
    func add(_ request: UNNotificationRequest) async throws
}

public struct LiveLocalNotificationScheduler: LocalNotificationScheduling {
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
