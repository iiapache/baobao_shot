import Foundation

// MARK: - Models

public struct CreditBalanceData: Decodable, Sendable, Equatable {
    public let balance: Int
    public let signInAvailable: Bool

    public init(balance: Int, signInAvailable: Bool) {
        self.balance = balance
        self.signInAvailable = signInAvailable
    }
}

public struct CreditTransactionItem: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let type: String
    public let amount: Int
    public let refKind: String?
    public let refId: String?
    public let balanceAfter: Int
    public let createdAt: String

    public init(
        id: String,
        type: String,
        amount: Int,
        refKind: String? = nil,
        refId: String? = nil,
        balanceAfter: Int,
        createdAt: String
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.refKind = refKind
        self.refId = refId
        self.balanceAfter = balanceAfter
        self.createdAt = createdAt
    }
}

public struct CreditTransactionsData: Decodable, Sendable, Equatable {
    public let items: [CreditTransactionItem]
    public let nextCursor: String?

    public init(items: [CreditTransactionItem], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct IAPVerifyRequest: Encodable, Sendable, Equatable {
    public let transactionId: String
    public let signedTransaction: String
    public let productId: String

    public init(transactionId: String, signedTransaction: String, productId: String) {
        self.transactionId = transactionId
        self.signedTransaction = signedTransaction
        self.productId = productId
    }
}

public struct CreditSignInData: Decodable, Sendable, Equatable {
    public let grantedCredits: Int
    public let balanceAfter: Int
    public let streak: Int
    public let ledgerId: String

    public init(grantedCredits: Int, balanceAfter: Int, streak: Int, ledgerId: String) {
        self.grantedCredits = grantedCredits
        self.balanceAfter = balanceAfter
        self.streak = streak
        self.ledgerId = ledgerId
    }
}

public struct AdRewardRequest: Encodable, Sendable, Equatable {
    public let network: String
    public let placementId: String
    public let transId: String
    public let idfv: String

    public init(network: String, placementId: String, transId: String, idfv: String) {
        self.network = network
        self.placementId = placementId
        self.transId = transId
        self.idfv = idfv
    }
}

public struct AdRewardRequestContext: Sendable, Equatable {
    public let nonce: String
    public let timestampMs: Int64

    public init(nonce: String, timestampMs: Int64) {
        self.nonce = nonce
        self.timestampMs = timestampMs
    }
}

public struct AdRewardData: Decodable, Sendable, Equatable {
    public let grantedCredits: Int
    public let balanceAfter: Int
    public let ledgerId: String
    public let duplicate: Bool?

    public init(
        grantedCredits: Int,
        balanceAfter: Int,
        ledgerId: String,
        duplicate: Bool? = nil
    ) {
        self.grantedCredits = grantedCredits
        self.balanceAfter = balanceAfter
        self.ledgerId = ledgerId
        self.duplicate = duplicate
    }
}

public struct CreditDurationTierRate: Decodable, Sendable, Equatable {
    public let durationSeconds: Int
    public let creditCost: Int

    public init(durationSeconds: Int, creditCost: Int) {
        self.durationSeconds = durationSeconds
        self.creditCost = creditCost
    }
}

public struct CreditPlayRate: Decodable, Sendable, Equatable {
    public let playId: String
    public let kind: String
    public let creditCost: Int?
    public let durationTiers: [CreditDurationTierRate]?

    public init(
        playId: String,
        kind: String,
        creditCost: Int? = nil,
        durationTiers: [CreditDurationTierRate]? = nil
    ) {
        self.playId = playId
        self.kind = kind
        self.creditCost = creditCost
        self.durationTiers = durationTiers
    }
}

public struct CreditRatesData: Decodable, Sendable, Equatable {
    public let version: String
    public let plays: [CreditPlayRate]

    public init(version: String, plays: [CreditPlayRate]) {
        self.version = version
        self.plays = plays
    }

    /// 按玩法 ID 与视频时长解析远端单价；未命中时返回 nil。
    public func cost(for playId: String, durationSeconds: Int?) -> Int? {
        guard let play = plays.first(where: { $0.playId == playId }) else { return nil }
        if let tiers = play.durationTiers, !tiers.isEmpty {
            if let durationSeconds,
               let tier = tiers.first(where: { $0.durationSeconds == durationSeconds }) {
                return tier.creditCost
            }
            return tiers.map(\.creditCost).min()
        }
        return play.creditCost
    }
}

public struct IAPVerifyData: Decodable, Sendable, Equatable {
    public let grantedCredits: Int
    public let balanceAfter: Int
    public let transactionId: String
    public let ledgerId: String
    public let duplicate: Bool?

    public init(
        grantedCredits: Int,
        balanceAfter: Int,
        transactionId: String,
        ledgerId: String,
        duplicate: Bool? = nil
    ) {
        self.grantedCredits = grantedCredits
        self.balanceAfter = balanceAfter
        self.transactionId = transactionId
        self.ledgerId = ledgerId
        self.duplicate = duplicate
    }
}

// MARK: - Endpoint

enum CreditsEndpoint: Endpoint {
    case balance
    case transactions(cursor: String?, limit: Int)
    case rates
    case signIn
    case iapVerify(IAPVerifyRequest)
    case adReward(AdRewardRequest, AdRewardRequestContext)

    var path: String {
        switch self {
        case .balance:
            return "/v1/credits/balance"
        case .transactions:
            return "/v1/credits/transactions"
        case .rates:
            return "/v1/credits/rates"
        case .signIn:
            return "/v1/credits/sign-in"
        case .iapVerify:
            return "/v1/credits/iap-verify"
        case .adReward:
            return "/v1/credits/ad-reward"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .balance, .transactions, .rates:
            return .get
        case .signIn, .iapVerify, .adReward:
            return .post
        }
    }

    var headers: [String: String]? {
        switch self {
        case let .adReward(_, context):
            return [
                "X-Nonce": context.nonce,
                "X-Timestamp": String(context.timestampMs),
            ]
        default:
            return nil
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .balance, .rates, .signIn, .iapVerify, .adReward:
            return nil
        case let .transactions(cursor, limit):
            var items = [URLQueryItem(name: "limit", value: String(limit))]
            if let cursor, !cursor.isEmpty {
                items.append(URLQueryItem(name: "cursor", value: cursor))
            }
            return items
        }
    }

    func encodeBody(with encoder: JSONEncoder) throws -> Data? {
        switch self {
        case .balance, .transactions, .rates, .signIn:
            return nil
        case .iapVerify(let request):
            return try encoder.encode(request)
        case .adReward(let request, _):
            return try encoder.encode(request)
        }
    }
}

// MARK: - API

public struct CreditsAPI: Sendable {
    public static let defaultTransactionPageSize = 20

    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /v1/credits/balance
    public func balance() async throws -> CreditBalanceData {
        try await client.request(CreditsEndpoint.balance)
    }

    /// GET /v1/credits/transactions
    public func transactions(
        cursor: String? = nil,
        limit: Int = defaultTransactionPageSize
    ) async throws -> CreditTransactionsData {
        try await client.request(CreditsEndpoint.transactions(cursor: cursor, limit: limit))
    }

    /// GET /v1/credits/rates
    public func rates() async throws -> CreditRatesData {
        try await client.request(CreditsEndpoint.rates)
    }

    /// POST /v1/credits/sign-in
    public func signIn() async throws -> CreditSignInData {
        try await client.request(CreditsEndpoint.signIn)
    }

    /// POST /v1/credits/iap-verify
    public func iapVerify(_ request: IAPVerifyRequest) async throws -> IAPVerifyData {
        try await client.request(CreditsEndpoint.iapVerify(request))
    }

    /// POST /v1/credits/ad-reward
    public func adReward(
        _ request: AdRewardRequest,
        context: AdRewardRequestContext
    ) async throws -> AdRewardData {
        try await client.request(CreditsEndpoint.adReward(request, context))
    }
}
