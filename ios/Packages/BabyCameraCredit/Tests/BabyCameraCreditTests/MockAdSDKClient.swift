import Foundation
@testable import BabyCameraCredit

/// 可编程 mock，覆盖 stub 的默认行为。
final class MockAdSDKClient: AdSDKClient, @unchecked Sendable {
    let network: AdNetwork
    var initializeHandler: (@Sendable () async throws -> Void)?
    var loadHandler: (@Sendable (AdPlacement, String) async throws -> AdCreative)?
    var showHandler: (@Sendable (AdCreative) async throws -> AdShowResult)?

    init(network: AdNetwork) {
        self.network = network
    }

    func initialize() async throws {
        if let initializeHandler {
            try await initializeHandler()
        }
    }

    func load(placement: AdPlacement, placementID: String) async throws -> AdCreative {
        if let loadHandler {
            return try await loadHandler(placement, placementID)
        }
        return AdCreative(
            network: network,
            placement: placement,
            placementID: placementID,
            transactionID: "mock-\(network.rawValue)-\(placement.rawValue)"
        )
    }

    func show(_ creative: AdCreative) async throws -> AdShowResult {
        if let showHandler {
            return try await showHandler(creative)
        }
        return .impressed(transactionID: creative.transactionID)
    }
}
