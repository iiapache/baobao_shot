import Foundation

/// Staging / 真机联调用联盟 Bridge：无第三方 SDK 依赖，行为对齐真实激励回调与 SSV 流水号格式。
public struct StagingBridgeAdSDKClient: AdSDKClient, @unchecked Sendable {
    public let network: AdNetwork
    private let transactionIDFactory: @Sendable () -> String

    public init(
        network: AdNetwork,
        transactionIDFactory: @escaping @Sendable () -> String = {
            UUID().uuidString.lowercased()
        }
    ) {
        self.network = network
        self.transactionIDFactory = transactionIDFactory
    }

    public func initialize() async throws {}

    public func load(placement: AdPlacement, placementID: String) async throws -> AdCreative {
        guard !placementID.isEmpty else {
            throw AdManagerError.loadFailed("missing placement id for \(network.rawValue)")
        }
        let transactionID = makeTransactionID(placement: placement)
        return AdCreative(
            network: network,
            placement: placement,
            placementID: placementID,
            transactionID: transactionID
        )
    }

    public func show(_ creative: AdCreative) async throws -> AdShowResult {
        switch creative.placement {
        case .rewarded:
            return .rewarded(transactionID: creative.transactionID)
        case .splash, .interstitial:
            return .impressed(transactionID: creative.transactionID)
        }
    }

    private func makeTransactionID(placement: AdPlacement) -> String {
        let suffix = transactionIDFactory()
        switch placement {
        case .rewarded:
            return "\(network.rawValue)-staging-reward-\(suffix)"
        case .splash:
            return "\(network.rawValue)-staging-splash-\(suffix)"
        case .interstitial:
            return "\(network.rawValue)-staging-interstitial-\(suffix)"
        }
    }
}

public enum StagingBridgeAdSDKFactory {
    public static func makeCNClients() -> [AdSDKClient] {
        [
            StagingBridgeAdSDKClient(network: .pangle),
            StagingBridgeAdSDKClient(network: .gdt),
        ]
    }

    public static func makeOSClients() -> [AdSDKClient] {
        [StagingBridgeAdSDKClient(network: .admob)]
    }
}
