import BabyCameraNetwork
import Foundation

public struct NotificationServiceConfiguration: Sendable {
    public let region: AppRegion
    public let regionConfig: RegionConfig
    public let tokenStore: TokenStore
    public let session: URLSession

    public init(
        region: AppRegion = .cn,
        regionConfig: RegionConfig? = nil,
        tokenStore: TokenStore = KeychainTokenStore(),
        session: URLSession = .shared
    ) {
        self.region = region
        self.regionConfig = regionConfig ?? RegionConfig(
            region: region,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            deviceId: NotificationServiceConfiguration.resolveDeviceId()
        )
        self.tokenStore = tokenStore
        self.session = session
    }

    private static func resolveDeviceId() -> String {
        let key = "com.babycamera.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}

public final class NotificationService: NotificationServing, @unchecked Sendable {
    public private(set) var unreadCount: Int = 0

    private let regionConfig: RegionConfig
    private let tokenStore: TokenStore
    private let session: URLSession
    private let clientFactory: @Sendable (TokenStore) -> APIClient
    private let unreadLock = NSLock()

    public init(
        configuration: NotificationServiceConfiguration = NotificationServiceConfiguration(),
        clientFactory: (@Sendable (TokenStore) -> APIClient)? = nil
    ) {
        self.regionConfig = configuration.regionConfig
        self.tokenStore = configuration.tokenStore
        self.session = configuration.session
        self.clientFactory = clientFactory ?? { tokenStore in
            makeAuthenticatedClient(
                region: configuration.region,
                tokenStore: tokenStore,
                regionConfig: configuration.regionConfig,
                session: configuration.session
            )
        }
    }

    public func refreshUnreadCount() async throws {
        let data = try await api().list(limit: 1)
        setUnreadCount(data.unreadCount)
    }

    public func listNotifications(cursor: String? = nil) async throws -> NotificationListData {
        let data = try await api().list(cursor: cursor)
        setUnreadCount(data.unreadCount)
        return data
    }

    public func markAllRead() async throws -> MarkNotificationsReadData {
        let data = try await api().markRead()
        setUnreadCount(data.unreadCount)
        return data
    }

    public func loadCategorySubscriptions() async throws -> [NotificationCategory] {
        let data = try await api().subscriptions()
        return NotificationCategory.merge(remote: data.subscriptions)
    }

    public func updateCategory(
        _ category: NotificationCategoryCode,
        enabled: Bool
    ) async throws -> [NotificationCategory] {
        guard NotificationCategory.userCanDisable(category) || enabled else {
            throw NotificationServiceError.categoryLocked(category)
        }

        let data = try await api().updateSubscriptions(
            UpdateNotificationSubscriptionsRequest(
                subscriptions: [NotificationSubscriptionItem(category: category, enabled: enabled)]
            )
        )
        return NotificationCategory.merge(remote: data.subscriptions)
    }

    private func api() throws -> NotificationsAPI {
        guard tokenStore.refreshToken() != nil else {
            throw NotificationServiceError.notAuthenticated
        }
        return NotificationsAPI(client: clientFactory(tokenStore))
    }

    private func setUnreadCount(_ count: Int) {
        unreadLock.lock()
        defer { unreadLock.unlock() }
        unreadCount = count
    }
}
