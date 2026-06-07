import BabyCameraNetwork
import Foundation
import UserNotifications
@testable import BabyCameraNotification

final class MockNotificationService: NotificationServing, @unchecked Sendable {
    var unreadCount: Int = 0
    var listHandler: ((String?) throws -> NotificationListData)?
    var markReadHandler: (() throws -> MarkNotificationsReadData)?
    var subscriptionsHandler: (() throws -> [NotificationCategory])?
    var updateHandler: ((NotificationCategoryCode, Bool) throws -> [NotificationCategory])?

    var listCallCount = 0
    var markReadCallCount = 0

    func refreshUnreadCount() async throws {
        unreadCount = try await listNotifications(cursor: nil).unreadCount
    }

    func listNotifications(cursor: String?) async throws -> NotificationListData {
        listCallCount += 1
        if let listHandler {
            return try listHandler(cursor)
        }
        return NotificationListData(items: [], unreadCount: unreadCount)
    }

    func markAllRead() async throws -> MarkNotificationsReadData {
        markReadCallCount += 1
        if let markReadHandler {
            return try markReadHandler()
        }
        unreadCount = 0
        return MarkNotificationsReadData(markedCount: 1, unreadCount: 0)
    }

    func loadCategorySubscriptions() async throws -> [NotificationCategory] {
        if let subscriptionsHandler {
            return try subscriptionsHandler()
        }
        return NotificationCategory.allDefaults
    }

    func updateCategory(_ category: NotificationCategoryCode, enabled: Bool) async throws -> [NotificationCategory] {
        if let updateHandler {
            return try updateHandler(category, enabled)
        }
        throw NotificationServiceError.categoryLocked(category)
    }
}

final class MockAPNsTokenProvider: APNsTokenProviding {
    var token: Data?

    init(token: Data? = nil) {
        self.token = token
    }

    func currentToken() async -> Data? {
        token
    }
}

struct MockDeviceMetadata: DeviceMetadataProviding {
    let deviceId: String
    let appVersion: String
    let osVersion: String
    let model: String
}

final class MockLocalNotificationScheduler: LocalNotificationScheduling, @unchecked Sendable {
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

final class MockDailyPhotoReminderPreferencesStore: DailyPhotoReminderPreferencesStoring, @unchecked Sendable {
    private(set) var saved: DailyPhotoReminderPreferences?
    var stored = DailyPhotoReminderPreferences()

    func load() -> DailyPhotoReminderPreferences {
        saved ?? stored
    }

    func save(_ preferences: DailyPhotoReminderPreferences) {
        saved = preferences
        stored = preferences
    }
}

final class MockUninstallReminderPreferencesStore: UninstallReminderPreferencesStoring, @unchecked Sendable {
    private(set) var saved: UninstallReminderPreferences?
    var stored = UninstallReminderPreferences()

    func load() -> UninstallReminderPreferences {
        saved ?? stored
    }

    func save(_ preferences: UninstallReminderPreferences) {
        saved = preferences
        stored = preferences
    }
}

final class MockBackgroundRefreshScheduler: BackgroundRefreshScheduling, @unchecked Sendable {
    private(set) var registeredIdentifiers: [String] = []
    private(set) var submittedRequests: [BackgroundRefreshRequest] = []
    var submitResult = true
    var handler: (@Sendable () async -> Bool)?

    func register(
        identifier: String,
        handler: @escaping @Sendable () async -> Bool
    ) {
        registeredIdentifiers.append(identifier)
        self.handler = handler
    }

    func submit(_ request: BackgroundRefreshRequest) async -> Bool {
        submittedRequests.append(request)
        return submitResult
    }
}

struct MockNotificationClock: NotificationClock {
    var fixedDate: Date

    init(fixedDate: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.fixedDate = fixedDate
    }

    func now() -> Date { fixedDate }
}

final class MockAIResultBackgroundExecutor: AIResultBackgroundRefreshExecuting, @unchecked Sendable {
    private(set) var executedPayloads: [[RemotePushPayload]] = []
    var result = true

    func execute(_ payloads: [RemotePushPayload]) async -> Bool {
        executedPayloads.append(payloads)
        return result
    }
}
