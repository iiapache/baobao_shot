import BabyCameraNetwork
import Foundation

public struct SubscriptionStoreConfiguration: Sendable {
    public let region: AppRegion
    public let regionConfig: RegionConfig
    public let tokenStore: TokenStore
    public let session: URLSession
    public let maxVerifyRetries: Int
    public let retryBaseDelay: TimeInterval
    public let appAttestAttachmentProvider: AppAttestAttachmentProvider?

    public init(
        region: AppRegion = .cn,
        regionConfig: RegionConfig? = nil,
        tokenStore: TokenStore = KeychainTokenStore(),
        session: URLSession = .shared,
        maxVerifyRetries: Int = 3,
        retryBaseDelay: TimeInterval = 0.5,
        appAttestAttachmentProvider: AppAttestAttachmentProvider? = nil
    ) {
        self.region = region
        self.regionConfig = regionConfig ?? RegionConfig(
            region: region,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            deviceId: SubscriptionStoreConfiguration.resolveDeviceId()
        )
        self.tokenStore = tokenStore
        self.session = session
        self.maxVerifyRetries = max(1, maxVerifyRetries)
        self.retryBaseDelay = retryBaseDelay
        self.appAttestAttachmentProvider = appAttestAttachmentProvider
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

/// 订阅单一事实源：状态机 + 权益缓存 + 去广告 / 品牌水印联动（T4.13）。
@MainActor
public final class SubscriptionStore: ObservableObject, SubscriptionServing {
    @Published public private(set) var state: SubscriptionState = .none
    @Published public private(set) var entitlements: SubscriptionEntitlements = .empty
    @Published public private(set) var isActive = false
    @Published public private(set) var sku: String?
    @Published public private(set) var periodEnd: String?
    @Published public private(set) var autoRenew = false
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var brandWatermarkVisible = true

    public var isEntitled: Bool { state.isEntitled && isActive }

    /// 供 AdManager（T4.15）读取：有效订阅且含 removeAds 权益时不展示广告。
    public var shouldShowAds: Bool {
        !(isEntitled && entitlements.removeAds)
    }

    public let tokenStore: TokenStore
    public let region: AppRegion

    private let regionConfig: RegionConfig
    private let session: URLSession
    private let cache: any SubscriptionEntitlementCaching
    private let storeClient: IAPStoreClient
    private let clientFactory: @Sendable (TokenStore) -> APIClient
    private let maxVerifyRetries: Int
    private let retryBaseDelay: TimeInterval
    private let appAttestAttachmentProvider: AppAttestAttachmentProvider?
    private let brandWatermarkPreferenceKey = "com.babycamera.subscription.brandWatermarkVisible"
    private let now: () -> Date

    public init(
        configuration: SubscriptionStoreConfiguration = SubscriptionStoreConfiguration(),
        cache: any SubscriptionEntitlementCaching = SubscriptionEntitlementCache(),
        storeClient: IAPStoreClient = StoreKitPurchaseClient(),
        clientFactory: (@Sendable (TokenStore) -> APIClient)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.region = configuration.region
        self.regionConfig = configuration.regionConfig
        self.tokenStore = configuration.tokenStore
        self.session = configuration.session
        self.cache = cache
        self.storeClient = storeClient
        self.maxVerifyRetries = configuration.maxVerifyRetries
        self.retryBaseDelay = configuration.retryBaseDelay
        self.appAttestAttachmentProvider = configuration.appAttestAttachmentProvider
        self.now = now
        self.clientFactory = clientFactory ?? { tokenStore in
            makeAuthenticatedClient(
                region: configuration.region,
                tokenStore: tokenStore,
                regionConfig: configuration.regionConfig,
                session: configuration.session
            )
        }

        brandWatermarkVisible = UserDefaults.standard.object(forKey: brandWatermarkPreferenceKey) as? Bool ?? true
        restoreFromCache()
    }

    /// 启动时恢复缓存并后台刷新。
    public func bootstrap() async {
        restoreFromCache()
        do {
            try await refreshIfNeeded()
        } catch {
            // 保留缓存或默认非订阅态，等待下次显式刷新
        }
    }

    public func refreshIfNeeded() async throws {
        if let cached = cache.load(), cache.isValid(cached, now: now()) {
            applySnapshot(cached)
            return
        }
        try await refresh()
    }

    public func refresh() async throws {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let data = try await api().me()
        let snapshot = SubscriptionSnapshot(me: data, fetchedAt: now())
        cache.save(snapshot)
        applySnapshot(snapshot)
    }

    public func fetchProducts() async throws -> [SubscriptionListedProduct] {
        try await api().products().products
    }

    /// StoreKit 订阅购买 → POST /v1/subscriptions/iap-verify → 更新状态机。
    public func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        let transaction = try await storeClient.purchase(productID: productID)
        return try await verifySubscriptionTransaction(transaction)
    }

    public func verifySubscriptionTransaction(_ transaction: IAPVerifiedTransaction) async throws -> SubscriptionPurchaseOutcome {
        let verifyData = try await verifyWithRetry(transaction)
        try await storeClient.finish(transactionID: transaction.storeTransactionID)
        applyVerifyData(verifyData)
        return SubscriptionPurchaseOutcome(transaction: transaction, verifyData: verifyData)
    }

    public func applyVerifyData(_ verifyData: SubscriptionIAPVerifyData) {
        let snapshot = SubscriptionSnapshot(verify: verifyData, fetchedAt: now())
        cache.save(snapshot)
        applySnapshot(snapshot)
    }

    /// 用户关闭品牌水印（需 `brandWatermarkRemovable` 权益）。
    public func setBrandWatermarkVisible(_ visible: Bool) {
        brandWatermarkVisible = visible
        UserDefaults.standard.set(visible, forKey: brandWatermarkPreferenceKey)
    }

    /// 传给 `WatermarkRenderer.drawAllWatermarks(isSubscribed:)`。
    public func watermarkIsSubscribed() -> Bool {
        isEntitled
    }

    /// 传给 `SubscriptionBrandWatermarkPolicy(brandWatermarkEnabled:)`。
    public func watermarkBrandEnabled() -> Bool {
        guard isEntitled, entitlements.brandWatermarkRemovable else {
            return true
        }
        return brandWatermarkVisible
    }

    private func restoreFromCache() {
        guard let cached = cache.load() else {
            applySnapshot(.inactive)
            return
        }
        applySnapshot(cached)
    }

    private func applySnapshot(_ snapshot: SubscriptionSnapshot) {
        state = snapshot.state
        entitlements = snapshot.entitlements
        isActive = snapshot.active
        sku = snapshot.sku
        periodEnd = snapshot.periodEnd
        autoRenew = snapshot.autoRenew
    }

    private func verifyWithRetry(_ transaction: IAPVerifiedTransaction) async throws -> SubscriptionIAPVerifyData {
        var lastError: Error = SubscriptionStoreError.verifyFailed

        for attempt in 0..<maxVerifyRetries {
            do {
                return try await verify(transaction)
            } catch let error as SubscriptionStoreError where error == .nonRetriableVerifyFailure {
                throw error
            } catch {
                lastError = error
                guard shouldRetry(error), attempt < maxVerifyRetries - 1 else {
                    throw error
                }
                let delay = retryBaseDelay * pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError
    }

    private func verify(_ transaction: IAPVerifiedTransaction) async throws -> SubscriptionIAPVerifyData {
        guard tokenStore.refreshToken() != nil else {
            throw SubscriptionStoreError.notAuthenticated
        }

        let api = SubscriptionsAPI(client: clientFactory(tokenStore))
        do {
            let appAttest = await resolveAppAttestPayload(
                transactionId: transaction.transactionID,
                productId: transaction.productID
            )
            return try await api.iapVerify(
                SubscriptionIAPVerifyRequest(
                    transactionId: transaction.transactionID,
                    signedTransaction: transaction.signedTransaction,
                    productId: transaction.productID,
                    appAttest: appAttest
                )
            )
        } catch let error as APIError {
            if shouldRetry(error) {
                throw error
            }
            throw SubscriptionStoreError.nonRetriableVerifyFailure
        }
    }

    private func shouldRetry(_ error: Error) -> Bool {
        if error is NetworkTransportError {
            return true
        }
        guard let apiError = error as? APIError else {
            return false
        }
        if let status = apiError.httpStatusCode, status >= 500 {
            return true
        }
        switch apiError.code {
        case .sysInternal, .sysUpstreamUnavailable, .commonRateLimit:
            return true
        default:
            return false
        }
    }

    private func api() throws -> SubscriptionsAPI {
        guard tokenStore.refreshToken() != nil else {
            throw SubscriptionStoreError.notAuthenticated
        }
        return SubscriptionsAPI(client: clientFactory(tokenStore))
    }

    private func resolveAppAttestPayload(
        transactionId: String,
        productId: String
    ) async -> AppAttestPayload? {
        guard let provider = appAttestAttachmentProvider else {
            return nil
        }
        guard let attachment = await provider(transactionId, productId) else {
            return nil
        }
        return AppAttestPayload(attachment: attachment)
    }
}
