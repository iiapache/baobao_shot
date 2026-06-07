import Foundation

// MARK: - Models

public struct SubscriptionEntitlementsData: Decodable, Sendable, Equatable {
    public let removeAds: Bool
    public let brandWatermarkRemovable: Bool
    public let allFilters: Bool
    public let annualReviewRegen: Bool

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
}

public struct SubscriptionMeData: Decodable, Sendable, Equatable {
    public let active: Bool
    public let state: String
    public let sku: String?
    public let periodStart: String?
    public let periodEnd: String?
    public let autoRenew: Bool?
    public let cacheTtlSeconds: Int
    public let entitlements: SubscriptionEntitlementsData
    public let subscriptionId: String?

    public init(
        active: Bool,
        state: String,
        sku: String? = nil,
        periodStart: String? = nil,
        periodEnd: String? = nil,
        autoRenew: Bool? = nil,
        cacheTtlSeconds: Int,
        entitlements: SubscriptionEntitlementsData,
        subscriptionId: String? = nil
    ) {
        self.active = active
        self.state = state
        self.sku = sku
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.autoRenew = autoRenew
        self.cacheTtlSeconds = cacheTtlSeconds
        self.entitlements = entitlements
        self.subscriptionId = subscriptionId
    }
}

public struct SubscriptionIAPVerifyRequest: Encodable, Sendable, Equatable {
    public let transactionId: String
    public let signedTransaction: String
    public let productId: String
    public let appAttest: AppAttestPayload?

    public init(
        transactionId: String,
        signedTransaction: String,
        productId: String,
        appAttest: AppAttestPayload? = nil
    ) {
        self.transactionId = transactionId
        self.signedTransaction = signedTransaction
        self.productId = productId
        self.appAttest = appAttest
    }
}

public struct SubscriptionIAPVerifyData: Decodable, Sendable, Equatable {
    public let subscriptionId: String
    public let state: String
    public let sku: String
    public let periodStart: String
    public let periodEnd: String
    public let autoRenew: Bool
    public let entitlements: SubscriptionEntitlementsData
    public let duplicate: Bool?

    public init(
        subscriptionId: String,
        state: String,
        sku: String,
        periodStart: String,
        periodEnd: String,
        autoRenew: Bool,
        entitlements: SubscriptionEntitlementsData,
        duplicate: Bool? = nil
    ) {
        self.subscriptionId = subscriptionId
        self.state = state
        self.sku = sku
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.autoRenew = autoRenew
        self.entitlements = entitlements
        self.duplicate = duplicate
    }
}

public struct SubscriptionListedProduct: Decodable, Sendable, Equatable, Identifiable {
    public let productId: String
    public let name: String
    public let period: String
    public let priceCny: Int?
    public let bonusCredits: Int?
    public let regions: [String]

    public var id: String { productId }

    public init(
        productId: String,
        name: String,
        period: String,
        priceCny: Int? = nil,
        bonusCredits: Int? = nil,
        regions: [String]
    ) {
        self.productId = productId
        self.name = name
        self.period = period
        self.priceCny = priceCny
        self.bonusCredits = bonusCredits
        self.regions = regions
    }
}

public struct SubscriptionProductsData: Decodable, Sendable, Equatable {
    public let region: String
    public let products: [SubscriptionListedProduct]

    public init(region: String, products: [SubscriptionListedProduct]) {
        self.region = region
        self.products = products
    }
}

// MARK: - Endpoint

enum SubscriptionsEndpoint: Endpoint {
    case me
    case iapVerify(SubscriptionIAPVerifyRequest)
    case products

    var path: String {
        switch self {
        case .me:
            return "/v1/subscriptions/me"
        case .iapVerify:
            return "/v1/subscriptions/iap-verify"
        case .products:
            return "/v1/subscriptions/products"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .me, .products:
            return .get
        case .iapVerify:
            return .post
        }
    }

    var queryItems: [URLQueryItem]? { nil }

    func encodeBody(with encoder: JSONEncoder) throws -> Data? {
        switch self {
        case .me, .products:
            return nil
        case .iapVerify(let request):
            return try encoder.encode(request)
        }
    }
}

// MARK: - API

public struct SubscriptionsAPI: Sendable {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /v1/subscriptions/me
    public func me() async throws -> SubscriptionMeData {
        try await client.request(SubscriptionsEndpoint.me)
    }

    /// POST /v1/subscriptions/iap-verify
    public func iapVerify(_ request: SubscriptionIAPVerifyRequest) async throws -> SubscriptionIAPVerifyData {
        try await client.request(SubscriptionsEndpoint.iapVerify(request))
    }

    /// GET /v1/subscriptions/products
    public func products() async throws -> SubscriptionProductsData {
        try await client.request(SubscriptionsEndpoint.products)
    }
}
