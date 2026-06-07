import XCTest
@testable import BabyCameraCredit

final class AdSDKClientFactoryTests: XCTestCase {
    func testForceStubUsesStubClientsAndUnitIDs() {
        let clients = AdSDKClientFactory.makeClients(
            region: .cn,
            forceStub: true,
            useLiveSDKOverride: true
        )
        XCTAssertEqual(clients.count, 2)
        XCTAssertTrue(clients[0] is StubAdSDKClient)

        let unitIDs = AdSDKClientFactory.resolveUnitIDs(
            region: .cn,
            forceStub: true,
            useLiveSDKOverride: true
        )
        XCTAssertEqual(unitIDs.rewarded.placementID, "pangle_rewarded_stub")
    }

    func testFeatureFlagDisabledUsesStub() {
        let clients = AdSDKClientFactory.makeClients(
            region: .cn,
            featureFlagEnabled: false,
            useLiveSDKOverride: true
        )
        XCTAssertTrue(clients[0] is StubAdSDKClient)
    }

    func testFeatureFlagEnabledUsesLiveBridge() {
        let clients = AdSDKClientFactory.makeClients(
            region: .cn,
            featureFlagEnabled: true,
            useLiveSDKOverride: false
        )
        XCTAssertTrue(clients[0] is StagingBridgeAdSDKClient)
    }

    func testLiveModeUsesStagingPlacementIDs() {
        let unitIDs = AdSDKClientFactory.resolveUnitIDs(
            region: .cn,
            useLiveSDKOverride: true
        )
        XCTAssertEqual(unitIDs.rewarded.placementID, "945494739")
        XCTAssertEqual(unitIDs.splash.placementID, "887367774")
    }

    func testResolveBackendModePriority() {
        XCTAssertEqual(
            AdConfiguration.resolveBackendMode(forceStub: true),
            .stub
        )
        XCTAssertEqual(
            AdConfiguration.resolveBackendMode(featureFlagEnabled: false, forceStub: false),
            .stub
        )
        XCTAssertEqual(
            AdConfiguration.resolveBackendMode(
                useLiveSDKFromInfoPlist: true,
                featureFlagEnabled: nil,
                forceStub: false
            ),
            .liveSDK
        )
        XCTAssertEqual(
            AdConfiguration.resolveBackendMode(
                useLiveSDKFromInfoPlist: false,
                featureFlagEnabled: nil,
                forceStub: false
            ),
            .stub
        )
    }

    func testOSLiveModeUsesAdMobBridge() {
        let clients = AdSDKClientFactory.makeClients(
            region: .os,
            useLiveSDKOverride: true
        )
        XCTAssertEqual(clients.count, 1)
        XCTAssertTrue(clients[0] is StagingBridgeAdSDKClient)
        XCTAssertEqual(clients[0].network, .admob)
    }
}
