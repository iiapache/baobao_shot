import Foundation

/// 微信 OpenSDK 运行模式：stub（单测/未链接 SDK）或 live（真机 OpenSDK）。
public enum WechatOpenSDKMode: String, Sendable, Equatable {
    case stub
    case live
}

public enum WechatOpenSDKConfiguration {
    public static let useOpenSDKInfoPlistKey = "WechatUseOpenSDK"
    public static let appIDInfoPlistKey = "WechatAppID"
    public static let universalLinkInfoPlistKey = "WechatUniversalLink"

    public static func useOpenSDKFromInfoPlist(bundle: Bundle = .main) -> Bool {
        parseBool(bundle.infoDictionary?[useOpenSDKInfoPlistKey] as? String, defaultValue: false)
    }

    public static func appIDFromInfoPlist(bundle: Bundle = .main) -> String? {
        parseNonEmpty(bundle.infoDictionary?[appIDInfoPlistKey] as? String)
    }

    public static func universalLinkFromInfoPlist(bundle: Bundle = .main) -> String? {
        parseNonEmpty(bundle.infoDictionary?[universalLinkInfoPlistKey] as? String)
    }

    public static func shareConfiguration(bundle: Bundle = .main) -> WechatShareConfiguration {
        let appID = appIDFromInfoPlist(bundle: bundle) ?? WechatShareConfiguration.default.appID
        let universalLink =
            universalLinkFromInfoPlist(bundle: bundle) ?? WechatShareConfiguration.default.universalLink
        return WechatShareConfiguration(appID: appID, universalLink: universalLink)
    }

    /// Info.plist（xcconfig）优先；未链接 WechatOpenSDK 时强制 stub。
    public static func resolveMode(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        useOpenSDKOverride: Bool? = nil
    ) -> WechatOpenSDKMode {
        if forceStub {
            return .stub
        }
        let wantsLive = useOpenSDKOverride ?? useOpenSDKFromInfoPlist(bundle: bundle)
        guard wantsLive else {
            return .stub
        }
        #if canImport(WechatOpenSDK)
        return .live
        #else
        return .stub
        #endif
    }

    private static func parseBool(_ raw: String?, defaultValue: Bool) -> Bool {
        guard let raw else { return defaultValue }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty || normalized.hasPrefix("$(") {
            return defaultValue
        }
        switch normalized {
        case "yes", "1", "true":
            return true
        case "no", "0", "false":
            return false
        default:
            return defaultValue
        }
    }

    private static func parseNonEmpty(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("$(") {
            return nil
        }
        return trimmed
    }
}
