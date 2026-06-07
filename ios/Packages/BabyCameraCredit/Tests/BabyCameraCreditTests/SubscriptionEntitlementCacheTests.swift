import Foundation
import XCTest
@testable import BabyCameraCredit

final class SubscriptionEntitlementCacheTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        let suite = "SubscriptionEntitlementCacheTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    func testSaveLoadRoundTrip() {
        let cache = SubscriptionEntitlementCache(defaults: defaults, storageKey: "snapshot")
        let snapshot = SubscriptionSnapshot(
            active: true,
            state: .active,
            entitlements: SubscriptionEntitlements(
                removeAds: true,
                brandWatermarkRemovable: true,
                allFilters: true,
                annualReviewRegen: false
            ),
            cacheTtlSeconds: 600,
            fetchedAt: Date(timeIntervalSince1970: 100)
        )

        cache.save(snapshot)
        let loaded = cache.load()

        XCTAssertEqual(loaded, snapshot)
    }

    func testValidityRespectsTTL() {
        let cache = SubscriptionEntitlementCache(defaults: defaults, storageKey: "snapshot")
        let fetchedAt = Date(timeIntervalSince1970: 1_000)
        let snapshot = SubscriptionSnapshot(
            active: true,
            state: .active,
            entitlements: .empty,
            cacheTtlSeconds: 600,
            fetchedAt: fetchedAt
        )

        XCTAssertTrue(cache.isValid(snapshot, now: fetchedAt.addingTimeInterval(599)))
        XCTAssertFalse(cache.isValid(snapshot, now: fetchedAt.addingTimeInterval(600)))
    }

    func testClearRemovesSnapshot() {
        let cache = SubscriptionEntitlementCache(defaults: defaults, storageKey: "snapshot")
        cache.save(
            SubscriptionSnapshot(
                active: false,
                state: .expired,
                entitlements: .empty,
                cacheTtlSeconds: 600,
                fetchedAt: Date()
            )
        )
        cache.clear()
        XCTAssertNil(cache.load())
    }
}
