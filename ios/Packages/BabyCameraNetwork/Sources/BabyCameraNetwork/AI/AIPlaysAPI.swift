import Foundation

// MARK: - Models

public struct AIPlayDurationTierData: Decodable, Sendable, Equatable {
    public let durationSeconds: Int
    public let creditCost: Int

    public init(durationSeconds: Int, creditCost: Int) {
        self.durationSeconds = durationSeconds
        self.creditCost = creditCost
    }
}

public struct AIPlayItemData: Decodable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let description: String?
    public let kind: String
    public let creditCost: Int?
    public let durationTiers: [AIPlayDurationTierData]?
    public let available: Bool

    public init(
        id: String,
        name: String,
        description: String? = nil,
        kind: String,
        creditCost: Int? = nil,
        durationTiers: [AIPlayDurationTierData]? = nil,
        available: Bool
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.kind = kind
        self.creditCost = creditCost
        self.durationTiers = durationTiers
        self.available = available
    }
}

public struct AIPlaysCatalogData: Decodable, Sendable, Equatable {
    public let version: String
    public let region: String
    public let ttlSeconds: Int
    public let plays: [AIPlayItemData]

    public init(
        version: String,
        region: String,
        ttlSeconds: Int,
        plays: [AIPlayItemData]
    ) {
        self.version = version
        self.region = region
        self.ttlSeconds = ttlSeconds
        self.plays = plays
    }
}

// MARK: - Endpoint

enum AIPlaysEndpoint: Endpoint {
    case listPlays

    var path: String {
        switch self {
        case .listPlays:
            return "/v1/ai/plays"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listPlays:
            return .get
        }
    }
}

// MARK: - API

public struct AIPlaysAPI: Sendable {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /v1/ai/plays
    public func listPlays() async throws -> AIPlaysCatalogData {
        try await client.request(AIPlaysEndpoint.listPlays)
    }
}
