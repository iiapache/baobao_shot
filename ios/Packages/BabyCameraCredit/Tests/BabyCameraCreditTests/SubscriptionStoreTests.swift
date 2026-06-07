import BabyCameraNetwork
import XCTest
@testable import BabyCameraCredit

@MainActor
final class SubscriptionStoreTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeStore(
        cache: SubscriptionEntitlementCache = SubscriptionEntitlementCache(
            defaults: UserDefaults(suiteName: "SubscriptionStoreTests.\(UUID().uuidString)")!,
            storageKey: "snapshot"
        ),
        tokenStore: TokenStore = InMemoryTokenStore(access: "access", refresh: "refresh"),
        now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_000_000) }
    ) -> SubscriptionStore {
        SubscriptionStore(
            configuration: SubscriptionStoreConfiguration(
                region: .cn,
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: tokenStore,
                session: MockURLProtocol.makeSession()
            ),
            cache: cache,
            storeClient: MockIAPStoreClient(),
            now: now
        )
    }

    func testRefreshUpdatesStateAndEntitlements() async throws {
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/subscriptions/me" else { return nil }
            return MockResponse(statusCode: 200, json: MockServer.subscriptionMeJSON())
        }

        let store = makeStore()
        try await store.refresh()

        XCTAssertTrue(store.isActive)
        XCTAssertEqual(store.state, .active)
        XCTAssertTrue(store.isEntitled)
        XCTAssertFalse(store.shouldShowAds)
        XCTAssertTrue(store.entitlements.brandWatermarkRemovable)
    }

    func testExpiredStateShowsAdsAndWatermark() async throws {
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/subscriptions/me" else { return nil }
            return MockResponse(
                statusCode: 200,
                json: MockServer.subscriptionMeJSON(
                    active: false,
                    state: "expired",
                    removeAds: false,
                    brandWatermarkRemovable: false
                )
            )
        }

        let store = makeStore()
        try await store.refresh()

        XCTAssertEqual(store.state, .expired)
        XCTAssertFalse(store.isEntitled)
        XCTAssertTrue(store.shouldShowAds)
        XCTAssertTrue(store.watermarkBrandEnabled())
    }

    func testEntitlementCacheSkipsNetworkWhenValid() async throws {
        var requestCount = 0
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/subscriptions/me" else { return nil }
            requestCount += 1
            return MockResponse(statusCode: 200, json: MockServer.subscriptionMeJSON())
        }

        let fixedNow = Date(timeIntervalSince1970: 2_000_000)
        let cache = SubscriptionEntitlementCache(
            defaults: UserDefaults(suiteName: "SubscriptionStoreTests.cache.\(UUID().uuidString)")!,
            storageKey: "snapshot"
        )
        cache.save(
            SubscriptionSnapshot(
                active: true,
                state: .active,
                sku: SubscriptionProductID.monthly,
                entitlements: SubscriptionEntitlements(
                    removeAds: true,
                    brandWatermarkRemovable: true,
                    allFilters: true,
                    annualReviewRegen: true
                ),
                cacheTtlSeconds: 600,
                fetchedAt: fixedNow
            )
        )

        let store = makeStore(cache: cache, now: { fixedNow.addingTimeInterval(120) })
        try await store.refreshIfNeeded()

        XCTAssertEqual(requestCount, 0)
        XCTAssertTrue(store.isEntitled)
    }

    func testEntitlementCacheExpiresAndRefreshes() async throws {
        var requestCount = 0
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/subscriptions/me" else { return nil }
            requestCount += 1
            return MockResponse(statusCode: 200, json: MockServer.subscriptionMeJSON())
        }

        let fetchedAt = Date(timeIntervalSince1970: 3_000_000)
        let cache = SubscriptionEntitlementCache(
            defaults: UserDefaults(suiteName: "SubscriptionStoreTests.expire.\(UUID().uuidString)")!,
            storageKey: "snapshot"
        )
        cache.save(
            SubscriptionSnapshot(
                active: false,
                state: .expired,
                entitlements: .empty,
                cacheTtlSeconds: 600,
                fetchedAt: fetchedAt
            )
        )

        let store = makeStore(cache: cache, now: { fetchedAt.addingTimeInterval(601) })
        try await store.refreshIfNeeded()

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(store.state, .active)
    }

    func testBrandWatermarkToggleRequiresEntitlement() async throws {
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/subscriptions/me" else { return nil }
            return MockResponse(statusCode: 200, json: MockServer.subscriptionMeJSON())
        }

        let store = makeStore()
        try await store.refresh()

        store.setBrandWatermarkVisible(false)
        XCTAssertFalse(store.brandWatermarkVisible)
        XCTAssertFalse(store.watermarkBrandEnabled())

        store.setBrandWatermarkVisible(true)
        XCTAssertTrue(store.watermarkBrandEnabled())
    }

    func testStateTransitionUpdatesAdAndWatermarkLinkage() async throws {
        var requestCount = 0
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/subscriptions/me" else { return nil }
            if requestCount == 0 {
                requestCount += 1
                return MockResponse(statusCode: 200, json: MockServer.subscriptionMeJSON(state: "grace"))
            }
            return MockResponse(
                statusCode: 200,
                json: MockServer.subscriptionMeJSON(active: false, state: "expired", removeAds: false, brandWatermarkRemovable: false)
            )
        }

        let store = makeStore()

        try await store.refresh()
        XCTAssertEqual(store.state, .grace)
        XCTAssertTrue(store.isEntitled)
        XCTAssertFalse(store.shouldShowAds)

        try await store.refresh()
        XCTAssertEqual(store.state, .expired)
        XCTAssertTrue(store.shouldShowAds)
        XCTAssertTrue(store.watermarkBrandEnabled())
    }

    func testApplyVerifyDataActivatesSubscription() {
        let store = makeStore()
        store.applyVerifyData(
            SubscriptionIAPVerifyData(
                subscriptionId: "sub_test",
                state: "active",
                sku: SubscriptionProductID.monthly,
                periodStart: "2026-06-01T00:00:00Z",
                periodEnd: "2026-07-01T00:00:00Z",
                autoRenew: true,
                entitlements: SubscriptionEntitlementsData(
                    removeAds: true,
                    brandWatermarkRemovable: true,
                    allFilters: true,
                    annualReviewRegen: true
                )
            )
        )

        XCTAssertEqual(store.state, .active)
        XCTAssertFalse(store.shouldShowAds)
    }

    func testSubscriptionStateMachineEntitlementFlags() {
        XCTAssertTrue(SubscriptionState.trial.isEntitled)
        XCTAssertTrue(SubscriptionState.active.isEntitled)
        XCTAssertTrue(SubscriptionState.grace.isEntitled)
        XCTAssertFalse(SubscriptionState.expired.isEntitled)
        XCTAssertFalse(SubscriptionState.refunded.isEntitled)
    }

    func testNotAuthenticatedThrows() async {
        let store = makeStore(tokenStore: InMemoryTokenStore())

        do {
            try await store.refresh()
            XCTFail("expected not authenticated")
        } catch let error as SubscriptionStoreError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
