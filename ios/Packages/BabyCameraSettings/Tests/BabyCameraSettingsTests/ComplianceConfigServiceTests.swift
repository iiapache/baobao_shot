import BabyCameraNetwork
import XCTest
@testable import BabyCameraSettings

final class ComplianceConfigServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testFetchComplianceConfigFromFeaturesEndpoint() async throws {
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/config/features" else { return nil }
            return MockResponse(
                statusCode: 200,
                json: """
                {
                  "code": "OK",
                  "requestId": "req_test",
                  "data": {
                    "version": "20250606001",
                    "ttlSeconds": 300,
                    "context": { "region": "cn", "userIdHash": 42 },
                    "features": {
                      "compliance.icp_number": {
                        "enabled": true,
                        "variant": "京ICP备12345678号-9A"
                      },
                      "compliance.algorithm_filing_summary": {
                        "enabled": true,
                        "variant": "算法备案办理中"
                      },
                      "compliance.policy_urls.privacy_cn": {
                        "enabled": true,
                        "variant": "https://policy.example.com/privacy-cn.html"
                      },
                      "compliance.policy_versions.privacy_cn": {
                        "enabled": true,
                        "variant": "v1.2.0"
                      },
                      "compliance.policy_versions.terms": {
                        "enabled": true,
                        "variant": "v1.2.0"
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
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device")
            ),
            session: MockURLProtocol.makeSession()
        )
        let service = ComplianceConfigService(client: client, region: .cn)

        let config = try await service.fetchComplianceConfig()

        XCTAssertEqual(config.icpNumber, "京ICP备12345678号-9A")
        XCTAssertEqual(config.algorithmFilingSummary, "算法备案办理中")
        XCTAssertEqual(config.privacyPolicyURL?.absoluteString, "https://policy.example.com/privacy-cn.html")
        XCTAssertEqual(config.privacyPolicyVersion, "v1.2.0")
        XCTAssertEqual(config.termsVersion, "v1.2.0")
    }
}
