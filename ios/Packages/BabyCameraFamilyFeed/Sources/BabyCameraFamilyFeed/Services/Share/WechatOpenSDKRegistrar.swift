import Foundation
#if canImport(WechatOpenSDK)
import WechatOpenSDK
#endif

/// 宿主 App 在启动与 URL/Universal Link 回调时调用，完成 WXApi 注册与分享结果回传（INT-05）。
public enum WechatOpenSDKRegistrar {
    public static func registerIfNeeded(bundle: Bundle = .main) {
        guard WechatOpenSDKConfiguration.resolveMode(bundle: bundle) == .live else {
            return
        }
        #if canImport(WechatOpenSDK)
        let configuration = WechatOpenSDKConfiguration.shareConfiguration(bundle: bundle)
        guard !configuration.appID.isEmpty,
              WechatUniversalLinkValidator.validate(configuration.universalLink) else {
            return
        }

        _ = WXApi.registerApp(configuration.appID, universalLink: configuration.universalLink)
        #endif
    }

    @discardableResult
    public static func handleOpenURL(_ url: URL, bundle: Bundle = .main) -> Bool {
        guard WechatOpenSDKConfiguration.resolveMode(bundle: bundle) == .live else {
            return false
        }
        #if canImport(WechatOpenSDK)
        return WXApi.handleOpen(url, delegate: WechatOpenSDKBridgeLive.shared)
        #else
        return false
        #endif
    }

    @discardableResult
    public static func handleUniversalLink(_ userActivity: NSUserActivity, bundle: Bundle = .main) -> Bool {
        guard WechatOpenSDKConfiguration.resolveMode(bundle: bundle) == .live else {
            return false
        }
        #if canImport(WechatOpenSDK)
        return WXApi.handleOpenUniversalLink(userActivity, delegate: WechatOpenSDKBridgeLive.shared)
        #else
        return false
        #endif
    }
}
