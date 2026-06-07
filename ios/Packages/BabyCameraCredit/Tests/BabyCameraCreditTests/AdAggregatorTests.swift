import BabyCameraNetwork
import XCTest
@testable import BabyCameraCredit

final class AdAggregatorTests: XCTestCase {
    func testCNWaterfallFallsBackToGDTWhenPangleFails() async throws {
        let pangle = MockAdSDKClient(network: .pangle)
        pangle.loadHandler = { _, _ in
            throw AdManagerError.loadFailed("pangle unavailable")
        }

        let gdt = MockAdSDKClient(network: .gdt)
        gdt.showHandler = { creative in
            .impressed(transactionID: creative.transactionID)
        }

        let aggregator = AdAggregator(
            clients: [pangle, gdt],
            unitIDs: .stub(region: .cn)
        )

        let result = try await aggregator.loadAndShow(placement: .splash)
        XCTAssertEqual(result.network, .gdt)
        XCTAssertEqual(result.transactionID, "mock-gdt-splash")
    }

    func testOSUsesAdMobOnly() {
        let aggregator = AdAggregator.makeDefault(region: .os)
        XCTAssertEqual(aggregator.orderedNetworks, [.admob])
    }
}
