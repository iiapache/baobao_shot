import Foundation

public enum WechatOpenSDKBridgeFactory {
    public static func makeBridge(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        useOpenSDKOverride: Bool? = nil
    ) -> any WechatOpenSDKBridging {
        switch WechatOpenSDKConfiguration.resolveMode(
            bundle: bundle,
            forceStub: forceStub,
            useOpenSDKOverride: useOpenSDKOverride
        ) {
        case .stub:
            return StubWechatOpenSDKBridge()
        case .live:
            #if canImport(WechatOpenSDK)
            return WechatOpenSDKBridgeLive.shared
            #else
            return StubWechatOpenSDKBridge()
            #endif
        }
    }
}
