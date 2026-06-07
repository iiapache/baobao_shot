import Foundation

public enum WechatShareAdapterFactory {
    public static func make(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        useOpenSDKOverride: Bool? = nil
    ) -> WechatShareAdapter {
        WechatShareAdapter(
            bridge: WechatOpenSDKBridgeFactory.makeBridge(
                bundle: bundle,
                forceStub: forceStub,
                useOpenSDKOverride: useOpenSDKOverride
            ),
            configuration: WechatOpenSDKConfiguration.shareConfiguration(bundle: bundle)
        )
    }

    public static func currentMode(
        bundle: Bundle = .main,
        forceStub: Bool = false
    ) -> WechatOpenSDKMode {
        WechatOpenSDKConfiguration.resolveMode(bundle: bundle, forceStub: forceStub)
    }
}
