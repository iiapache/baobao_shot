import BabyCameraNetwork
import Foundation

public enum AdManagerFactory {
    public static func make(
        region: AppRegion,
        regionConfig: RegionConfig,
        tokenStore: TokenStore,
        session: URLSession = .shared,
        isSubscribed: @escaping @Sendable () -> Bool = { false },
        bundle: Bundle = .main,
        forceStub: Bool = false,
        featureFlagEnabled: Bool? = nil
    ) -> AdManager {
        let unitIDs = AdSDKClientFactory.resolveUnitIDs(
            region: region,
            bundle: bundle,
            forceStub: forceStub,
            featureFlagEnabled: featureFlagEnabled
        )
        let clients = AdSDKClientFactory.makeClients(
            region: region,
            bundle: bundle,
            forceStub: forceStub,
            featureFlagEnabled: featureFlagEnabled
        )
        let configuration = AdManagerConfiguration(
            region: region,
            regionConfig: regionConfig,
            tokenStore: tokenStore,
            session: session,
            unitIDs: unitIDs,
            isSubscribed: isSubscribed
        )
        return AdManager(
            configuration: configuration,
            clients: clients
        )
    }
}
