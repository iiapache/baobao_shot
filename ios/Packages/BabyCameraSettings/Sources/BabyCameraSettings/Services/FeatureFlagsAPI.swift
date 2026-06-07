import BabyCameraNetwork
import Foundation

struct FeatureFlagResult: Decodable, Sendable, Equatable {
    let enabled: Bool
    let variant: String?
    /// Configured rollout target (0–100); present on `rollout.*` keys (T7.14).
    let rolloutPercent: Int?
}

struct FeatureFlagsPayload: Decodable, Sendable, Equatable {
    let version: String
    let ttlSeconds: Int
    let features: [String: FeatureFlagResult]

    static let aiPlaysRolloutKey = "rollout.ai_plays_percent"
    static let pricingVariantKey = "rollout.pricing_variant"

    /// Target AI plays rollout percent from config-svc (e.g. 1 on Phased Release D1).
    var aiPlaysRolloutPercent: Int? {
        features[Self.aiPlaysRolloutKey]?.rolloutPercent
    }

    /// Pricing A/B variant: `control` | `variant_a` | `variant_b`.
    var pricingVariant: String? {
        features[Self.pricingVariantKey]?.variant
    }

    /// Whether the current user is in the AI plays rollout bucket.
    var isInAIPlaysRollout: Bool {
        features[Self.aiPlaysRolloutKey]?.enabled ?? false
    }
}

enum ConfigEndpoint: Endpoint {
    case features

    var path: String {
        switch self {
        case .features:
            return "/v1/config/features"
        }
    }

    var method: HTTPMethod { .get }

    var authRequirement: AuthRequirement { .none }
}

struct FeatureFlagsAPI {
    let client: APIClient

    func fetchFeatures() async throws -> FeatureFlagsPayload {
        try await client.request(ConfigEndpoint.features)
    }
}
