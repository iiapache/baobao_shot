import Foundation

// MARK: - Models

public enum NotificationCategoryCode: String, Codable, Sendable, CaseIterable {
    case milestone = "MILESTONE"
    case familyActivity = "FAMILY_ACTIVITY"
    case aiDone = "AI_DONE"
    case credit = "CREDIT"
    case system = "SYSTEM"
}

public struct RegisterDeviceRequest: Encodable, Sendable, Equatable {
    public let deviceId: String
    public let apnsToken: String
    public let appVersion: String
    public let osVersion: String
    public let model: String

    public init(
        deviceId: String,
        apnsToken: String,
        appVersion: String,
        osVersion: String,
        model: String
    ) {
        self.deviceId = deviceId
        self.apnsToken = apnsToken
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.model = model
    }
}

public struct RegisterDeviceData: Decodable, Sendable, Equatable {
    public let deviceId: String
    public let apnsToken: String
    public let region: String

    public init(deviceId: String, apnsToken: String, region: String) {
        self.deviceId = deviceId
        self.apnsToken = apnsToken
        self.region = region
    }
}

public struct NotificationPayload: Decodable, Sendable, Equatable {
    public let title: String?
    public let body: String?
    public let deepLink: String?
    public let imageUrl: String?

    public init(
        title: String? = nil,
        body: String? = nil,
        deepLink: String? = nil,
        imageUrl: String? = nil
    ) {
        self.title = title
        self.body = body
        self.deepLink = deepLink
        self.imageUrl = imageUrl
    }
}

public struct NotificationItem: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let category: NotificationCategoryCode
    public let payload: NotificationPayload
    public let readAt: String?
    public let createdAt: String

    public init(
        id: String,
        category: NotificationCategoryCode,
        payload: NotificationPayload,
        readAt: String? = nil,
        createdAt: String
    ) {
        self.id = id
        self.category = category
        self.payload = payload
        self.readAt = readAt
        self.createdAt = createdAt
    }

    public var isUnread: Bool { readAt == nil }
}

public struct NotificationListData: Decodable, Sendable, Equatable {
    public let items: [NotificationItem]
    public let nextCursor: String?
    public let unreadCount: Int

    public init(items: [NotificationItem], nextCursor: String? = nil, unreadCount: Int) {
        self.items = items
        self.nextCursor = nextCursor
        self.unreadCount = unreadCount
    }
}

public struct MarkNotificationsReadRequest: Encodable, Sendable, Equatable {
    public let notificationIds: [String]?

    public init(notificationIds: [String]? = nil) {
        self.notificationIds = notificationIds
    }
}

public struct MarkNotificationsReadData: Decodable, Sendable, Equatable {
    public let markedCount: Int
    public let unreadCount: Int

    public init(markedCount: Int, unreadCount: Int) {
        self.markedCount = markedCount
        self.unreadCount = unreadCount
    }
}

public struct NotificationSubscriptionItem: Codable, Sendable, Equatable {
    public let category: NotificationCategoryCode
    public let enabled: Bool

    public init(category: NotificationCategoryCode, enabled: Bool) {
        self.category = category
        self.enabled = enabled
    }
}

public struct NotificationSubscriptionsData: Decodable, Sendable, Equatable {
    public let subscriptions: [NotificationSubscriptionItem]

    public init(subscriptions: [NotificationSubscriptionItem]) {
        self.subscriptions = subscriptions
    }
}

public struct UpdateNotificationSubscriptionsRequest: Encodable, Sendable, Equatable {
    public let subscriptions: [NotificationSubscriptionItem]

    public init(subscriptions: [NotificationSubscriptionItem]) {
        self.subscriptions = subscriptions
    }
}

// MARK: - Endpoint

enum NotificationsEndpoint: Endpoint {
    case registerDevice(RegisterDeviceRequest)
    case unregisterDevice(deviceId: String)
    case list(cursor: String?, limit: Int)
    case markRead(MarkNotificationsReadRequest)
    case getSubscriptions
    case updateSubscriptions(UpdateNotificationSubscriptionsRequest)

    var path: String {
        switch self {
        case .registerDevice:
            return "/v1/notifications/devices"
        case let .unregisterDevice(deviceId):
            return "/v1/notifications/devices/\(deviceId)"
        case .list:
            return "/v1/notifications"
        case .markRead:
            return "/v1/notifications/mark-read"
        case .getSubscriptions, .updateSubscriptions:
            return "/v1/notifications/subscriptions"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .registerDevice, .markRead:
            return .post
        case .unregisterDevice:
            return .delete
        case .list, .getSubscriptions:
            return .get
        case .updateSubscriptions:
            return .patch
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case let .list(cursor, limit):
            var items = [URLQueryItem(name: "limit", value: String(limit))]
            if let cursor, !cursor.isEmpty {
                items.append(URLQueryItem(name: "cursor", value: cursor))
            }
            return items
        default:
            return nil
        }
    }

    func encodeBody(with encoder: JSONEncoder) throws -> Data? {
        switch self {
        case let .registerDevice(request):
            return try encoder.encode(request)
        case let .markRead(request):
            return try encoder.encode(request)
        case let .updateSubscriptions(request):
            return try encoder.encode(request)
        case .unregisterDevice, .list, .getSubscriptions:
            return nil
        }
    }
}

// MARK: - API

public struct NotificationsAPI: Sendable {
    public static let defaultPageSize = 50

    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /v1/notifications/devices
    public func registerDevice(_ request: RegisterDeviceRequest) async throws -> RegisterDeviceData {
        try await client.request(NotificationsEndpoint.registerDevice(request))
    }

    /// DELETE /v1/notifications/devices/{deviceId}
    public func unregisterDevice(deviceId: String) async throws {
        _ = try await client.request(
            NotificationsEndpoint.unregisterDevice(deviceId: deviceId),
            responseType: EmptyData.self
        )
    }

    /// GET /v1/notifications
    public func list(
        cursor: String? = nil,
        limit: Int = defaultPageSize
    ) async throws -> NotificationListData {
        try await client.request(NotificationsEndpoint.list(cursor: cursor, limit: limit))
    }

    /// POST /v1/notifications/mark-read
    public func markRead(notificationIds: [String]? = nil) async throws -> MarkNotificationsReadData {
        try await client.request(
            NotificationsEndpoint.markRead(MarkNotificationsReadRequest(notificationIds: notificationIds))
        )
    }

    /// GET /v1/notifications/subscriptions
    public func subscriptions() async throws -> NotificationSubscriptionsData {
        try await client.request(NotificationsEndpoint.getSubscriptions)
    }

    /// PATCH /v1/notifications/subscriptions
    public func updateSubscriptions(
        _ request: UpdateNotificationSubscriptionsRequest
    ) async throws -> NotificationSubscriptionsData {
        try await client.request(NotificationsEndpoint.updateSubscriptions(request))
    }
}
