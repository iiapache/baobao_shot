import BabyCameraNetwork
import Foundation

/// 按区域选择联盟 SDK 并做瀑布加载（CN: 穿山甲 → 优量汇；OS: AdMob）。
public struct AdAggregator: Sendable {
    private let clients: [any AdSDKClient]
    private let unitIDs: AdUnitIDs

    public init(clients: [any AdSDKClient], unitIDs: AdUnitIDs) {
        self.clients = clients
        self.unitIDs = unitIDs
    }

    public static func makeDefault(
        region: AppRegion,
        unitIDs: AdUnitIDs? = nil,
        clients: [any AdSDKClient]? = nil
    ) -> AdAggregator {
        let resolvedUnitIDs = unitIDs ?? .stub(region: region)
        let resolvedClients: [any AdSDKClient]
        if let clients {
            resolvedClients = clients
        } else {
            switch region {
            case .cn:
                resolvedClients = StubAdSDKFactory.makeCNClients()
            case .os:
                resolvedClients = StubAdSDKFactory.makeOSClients()
            }
        }
        return AdAggregator(clients: resolvedClients, unitIDs: resolvedUnitIDs)
    }

    public var orderedNetworks: [AdNetwork] {
        clients.map(\.network)
    }

    public func initializeAll() async {
        for client in clients {
            try? await client.initialize()
        }
    }

    public func loadAndShow(placement: AdPlacement) async throws -> (network: AdNetwork, result: AdShowResult, transactionID: String) {
        let placementID = unitIDs.config(for: placement).placementID
        var lastError: Error = AdManagerError.sdkUnavailable

        for client in clients {
            do {
                let creative = try await client.load(placement: placement, placementID: placementID)
                let showResult = try await client.show(creative)
                let transactionID = resolveTransactionID(showResult, fallback: creative.transactionID)
                return (client.network, showResult, transactionID)
            } catch {
                lastError = error
            }
        }

        if let adError = lastError as? AdManagerError {
            throw adError
        }
        throw AdManagerError.loadFailed(String(describing: lastError))
    }

    private func resolveTransactionID(_ result: AdShowResult, fallback: String) -> String {
        switch result {
        case .rewarded(let transactionID), .impressed(let transactionID):
            return transactionID
        case .dismissed, .failed:
            return fallback
        }
    }
}
