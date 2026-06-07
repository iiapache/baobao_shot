import XCTest
@testable import BabyCameraCredit

final class IAPStoreClientFactoryTests: XCTestCase {
    func testForceStubOverridesInfoPlist() {
        let client = IAPStoreClientFactory.make(forceStub: true)
        XCTAssertTrue(client is StubIAPStoreClient)
    }

    func testFeatureFlagDisabledUsesStub() {
        let client = IAPStoreClientFactory.make(
            featureFlagEnabled: false,
            useStoreKitOverride: true
        )
        XCTAssertTrue(client is StubIAPStoreClient)
    }

    func testFeatureFlagEnabledUsesStoreKit() {
        let client = IAPStoreClientFactory.make(
            featureFlagEnabled: true,
            useStoreKitOverride: false
        )
        XCTAssertTrue(client is StoreKitPurchaseClient)
    }

    func testInfoPlistOverrideUsesStub() {
        let client = IAPStoreClientFactory.make(useStoreKitOverride: false)
        XCTAssertTrue(client is StubIAPStoreClient)
    }

    func testInfoPlistOverrideUsesStoreKit() {
        let client = IAPStoreClientFactory.make(useStoreKitOverride: true)
        XCTAssertTrue(client is StoreKitPurchaseClient)
    }

    func testResolveBackendModePriority() {
        XCTAssertEqual(
            IAPConfiguration.resolveBackendMode(forceStub: true),
            .stub
        )
        XCTAssertEqual(
            IAPConfiguration.resolveBackendMode(featureFlagEnabled: false, forceStub: false),
            .stub
        )
        XCTAssertEqual(
            IAPConfiguration.resolveBackendMode(
                useStoreKitFromInfoPlist: true,
                featureFlagEnabled: nil,
                forceStub: false
            ),
            .storeKit
        )
        XCTAssertEqual(
            IAPConfiguration.resolveBackendMode(
                useStoreKitFromInfoPlist: false,
                featureFlagEnabled: nil,
                forceStub: false
            ),
            .stub
        )
    }
}
