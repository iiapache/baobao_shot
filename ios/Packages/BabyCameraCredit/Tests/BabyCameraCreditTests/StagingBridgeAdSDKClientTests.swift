import XCTest
@testable import BabyCameraCredit

final class StagingBridgeAdSDKClientTests: XCTestCase {
    func testRewardedReturnsRewardedResult() async throws {
        let client = StagingBridgeAdSDKClient(
            network: .pangle,
            transactionIDFactory: { "tx-fixed" }
        )
        let creative = try await client.load(placement: .rewarded, placementID: "945494739")
        let result = try await client.show(creative)
        XCTAssertEqual(result, .rewarded(transactionID: "pangle-staging-reward-tx-fixed"))
    }

    func testSplashReturnsImpressedResult() async throws {
        let client = StagingBridgeAdSDKClient(network: .gdt)
        let creative = try await client.load(placement: .splash, placementID: "887367774")
        let result = try await client.show(creative)
        if case .impressed(let transactionID) = result {
            XCTAssertTrue(transactionID.hasPrefix("gdt-staging-splash-"))
        } else {
            XCTFail("expected impressed, got \(result)")
        }
    }
}
