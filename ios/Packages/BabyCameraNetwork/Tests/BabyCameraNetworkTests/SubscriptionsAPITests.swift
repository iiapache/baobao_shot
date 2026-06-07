import BabyCameraNetwork
import XCTest
@testable import BabyCameraNetwork

final class SubscriptionsAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeAPI() -> SubscriptionsAPI {
        let tokenStore = InMemoryTokenStore(access: "access", refresh: "refresh")
        let client = makeAuthenticatedClient(
            region: .cn,
            tokenStore: tokenStore,
            regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
            session: MockURLProtocol.makeSession()
        )
        return SubscriptionsAPI(client: client)
    }

    func testGetMe() async throws {
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/subscriptions/me" else { return nil }
            return MockResponse(statusCode: 200, json: MockServer.subscriptionMeJSON())
        }

        let data = try await makeAPI().me()
        XCTAssertTrue(data.active)
        XCTAssertEqual(data.state, "active")
        XCTAssertEqual(data.cacheTtlSeconds, 600)
        XCTAssertTrue(data.entitlements.removeAds)
        XCTAssertTrue(data.entitlements.brandWatermarkRemovable)
    }

    func testIAPVerify() async throws {
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/subscriptions/iap-verify" else { return nil }
            return MockResponse(statusCode: 200, json: MockServer.subscriptionIAPVerifyJSON())
        }

        let data = try await makeAPI().iapVerify(
            SubscriptionIAPVerifyRequest(
                transactionId: "2000000123456789",
                signedTransaction: "mock-jws",
                productId: SubscriptionProductID.monthly
            )
        )
        XCTAssertEqual(data.state, "active")
        XCTAssertEqual(data.sku, SubscriptionProductID.monthly)
        XCTAssertTrue(data.entitlements.removeAds)
    }

    func testListProducts() async throws {
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/subscriptions/products" else { return nil }
            return MockResponse(statusCode: 200, json: MockServer.subscriptionProductsJSON())
        }

        let data = try await makeAPI().products()
        XCTAssertEqual(data.region, "cn")
        XCTAssertEqual(data.products.count, 2)
        XCTAssertEqual(data.products[0].productId, SubscriptionProductID.monthly)
    }
}

private enum SubscriptionProductID {
    static let monthly = "com.baobao.sub.monthly"
}
