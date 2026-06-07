import BabyCameraNetwork
import Foundation

/// 与后端 `model.SubscriptionState` 对齐。
public enum SubscriptionState: String, Sendable, Equatable, Codable {
    case trial
    case active
    case grace
    case expired
    case refunded
    case none

    public init(rawServerValue: String?) {
        guard let rawServerValue, let parsed = SubscriptionState(rawValue: rawServerValue) else {
            self = .none
            return
        }
        self = parsed
    }

    /// trial / active / grace 视为有效订阅。
    public var isEntitled: Bool {
        switch self {
        case .trial, .active, .grace:
            return true
        case .expired, .refunded, .none:
            return false
        }
    }
}

public struct SubscriptionEntitlements: Sendable, Equatable, Codable {
    public let removeAds: Bool
    public let brandWatermarkRemovable: Bool
    public let allFilters: Bool
    public let annualReviewRegen: Bool

    public static let empty = SubscriptionEntitlements(
        removeAds: false,
        brandWatermarkRemovable: false,
        allFilters: false,
        annualReviewRegen: false
    )

    public init(
        removeAds: Bool,
        brandWatermarkRemovable: Bool,
        allFilters: Bool,
        annualReviewRegen: Bool
    ) {
        self.removeAds = removeAds
        self.brandWatermarkRemovable = brandWatermarkRemovable
        self.allFilters = allFilters
        self.annualReviewRegen = annualReviewRegen
    }

    init(data: SubscriptionEntitlementsData) {
        self.init(
            removeAds: data.removeAds,
            brandWatermarkRemovable: data.brandWatermarkRemovable,
            allFilters: data.allFilters,
            annualReviewRegen: data.annualReviewRegen
        )
    }
}

/// PRD §4.11 订阅 SKU，与后端 `subscription.ListProducts` 对齐。
public enum SubscriptionProductID {
    public static let monthly = "com.baobao.sub.monthly"
    public static let quarterly = "com.baobao.sub.quarterly"
    public static let yearly = "com.baobao.sub.yearly"
    public static let lifetime = "com.baobao.sub.lifetime"

    public static let all: Set<String> = [monthly, quarterly, yearly, lifetime]

    public static func isSubscriptionProduct(_ productID: String) -> Bool {
        all.contains(productID)
    }
}

public struct SubscriptionSnapshot: Sendable, Equatable, Codable {
    public let active: Bool
    public let state: SubscriptionState
    public let sku: String?
    public let periodStart: String?
    public let periodEnd: String?
    public let autoRenew: Bool
    public let entitlements: SubscriptionEntitlements
    public let subscriptionId: String?
    public let cacheTtlSeconds: Int
    public let fetchedAt: Date

    public init(
        active: Bool,
        state: SubscriptionState,
        sku: String? = nil,
        periodStart: String? = nil,
        periodEnd: String? = nil,
        autoRenew: Bool = false,
        entitlements: SubscriptionEntitlements,
        subscriptionId: String? = nil,
        cacheTtlSeconds: Int,
        fetchedAt: Date
    ) {
        self.active = active
        self.state = state
        self.sku = sku
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.autoRenew = autoRenew
        self.entitlements = entitlements
        self.subscriptionId = subscriptionId
        self.cacheTtlSeconds = cacheTtlSeconds
        self.fetchedAt = fetchedAt
    }

    init(me: SubscriptionMeData, fetchedAt: Date) {
        self.init(
            active: me.active,
            state: SubscriptionState(rawServerValue: me.state),
            sku: me.sku,
            periodStart: me.periodStart,
            periodEnd: me.periodEnd,
            autoRenew: me.autoRenew ?? false,
            entitlements: SubscriptionEntitlements(data: me.entitlements),
            subscriptionId: me.subscriptionId,
            cacheTtlSeconds: me.cacheTtlSeconds,
            fetchedAt: fetchedAt
        )
    }

    init(verify: SubscriptionIAPVerifyData, fetchedAt: Date, cacheTtlSeconds: Int = 600) {
        self.init(
            active: SubscriptionState(rawServerValue: verify.state).isEntitled,
            state: SubscriptionState(rawServerValue: verify.state),
            sku: verify.sku,
            periodStart: verify.periodStart,
            periodEnd: verify.periodEnd,
            autoRenew: verify.autoRenew,
            entitlements: SubscriptionEntitlements(data: verify.entitlements),
            subscriptionId: verify.subscriptionId,
            cacheTtlSeconds: cacheTtlSeconds,
            fetchedAt: fetchedAt
        )
    }

    public static let inactive = SubscriptionSnapshot(
        active: false,
        state: .none,
        entitlements: .empty,
        cacheTtlSeconds: 600,
        fetchedAt: .distantPast
    )
}

public enum SubscriptionStoreError: Error, Equatable, Sendable {
    case notAuthenticated
    case verifyFailed
    case nonRetriableVerifyFailure
}

public struct SubscriptionPurchaseOutcome: Sendable, Equatable {
    public let transaction: IAPVerifiedTransaction
    public let verifyData: SubscriptionIAPVerifyData

    public init(transaction: IAPVerifiedTransaction, verifyData: SubscriptionIAPVerifyData) {
        self.transaction = transaction
        self.verifyData = verifyData
    }
}
