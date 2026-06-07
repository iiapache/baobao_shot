import Foundation

public enum AdSDKClientFactory {
    public static func makeClients(
        region: AppRegion,
        bundle: Bundle = .main,
        forceStub: Bool = false,
        featureFlagEnabled: Bool? = nil,
        useLiveSDKOverride: Bool? = nil
    ) -> [AdSDKClient] {
        let mode = AdConfiguration.resolveBackendMode(
            useLiveSDKFromInfoPlist: useLiveSDKOverride ?? AdConfiguration.useLiveSDKFromInfoPlist(bundle: bundle),
            featureFlagEnabled: featureFlagEnabled,
            forceStub: forceStub
        )
        switch (mode, region) {
        case (.stub, .cn):
            return StubAdSDKFactory.makeCNClients()
        case (.stub, .os):
            return StubAdSDKFactory.makeOSClients()
        case (.liveSDK, .cn):
            return LiveAdSDKFactory.makeCNClients()
        case (.liveSDK, .os):
            return LiveAdSDKFactory.makeOSClients()
        }
    }

    public static func resolveUnitIDs(
        region: AppRegion,
        bundle: Bundle = .main,
        forceStub: Bool = false,
        featureFlagEnabled: Bool? = nil,
        useLiveSDKOverride: Bool? = nil
    ) -> AdUnitIDs {
        let mode = AdConfiguration.resolveBackendMode(
            useLiveSDKFromInfoPlist: useLiveSDKOverride ?? AdConfiguration.useLiveSDKFromInfoPlist(bundle: bundle),
            featureFlagEnabled: featureFlagEnabled,
            forceStub: forceStub
        )
        switch mode {
        case .stub:
            return .stub(region: region)
        case .liveSDK:
            return .fromInfoPlist(bundle: bundle, region: region)
        }
    }

    public static func currentMode(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        featureFlagEnabled: Bool? = nil
    ) -> AdBackendMode {
        AdConfiguration.resolveBackendMode(
            useLiveSDKFromInfoPlist: AdConfiguration.useLiveSDKFromInfoPlist(bundle: bundle),
            featureFlagEnabled: featureFlagEnabled,
            forceStub: forceStub
        )
    }
}
