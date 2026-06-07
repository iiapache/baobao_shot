import BabyCameraNetwork
import XCTest
@testable import BabyCameraSettings

final class FeatureFlagsAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testRolloutPercentAndPricingVariant() async throws {
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/config/features" else { return nil }
            return MockResponse(
                statusCode: 200,
                json: """
                {
                  "code": "OK",
                  "requestId": "req_rollout",
                  "data": {
                    "version": "20250606001",
                    "ttlSeconds": 300,
                    "context": { "region": "cn", "userIdHash": 12 },
                    "features": {
                      "rollout.ai_plays_percent": {
                        "enabled": true,
                        "variant": "10",
                        "rolloutPercent": 10
                      },
                      "rollout.pricing_variant": {
                        "enabled": false,
                        "variant": "variant_a",
                        "rolloutPercent": 50
                      }
                    }
                  }
                }
                """
            )
        }

        let client = APIClient(
            configuration: .standard(
                region: .cn,
                tokenStore: InMemoryTokenStore(),
                regionConfig: RegionConfig(region: .cn, appVersion: "1.5.0", deviceId: "test-device")
            ),
            session: MockURLProtocol.makeSession()
        )
        let payload = try await FeatureFlagsAPI(client: client).fetchFeatures()

        XCTAssertEqual(payload.aiPlaysRolloutPercent, 10)
        XCTAssertEqual(payload.pricingVariant, "variant_a")
        XCTAssertTrue(payload.isInAIPlaysRollout)
        XCTAssertEqual(payload.features["rollout.pricing_variant"]?.rolloutPercent, 50)
        XCTAssertFalse(payload.features["rollout.pricing_variant"]?.enabled ?? true)
    }
}
