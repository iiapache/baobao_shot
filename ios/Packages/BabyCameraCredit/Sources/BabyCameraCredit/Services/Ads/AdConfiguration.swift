import Foundation

/// 广告后端模式：联盟真实 SDK（或 Staging Bridge），或本地 stub。
public enum AdBackendMode: String, Sendable, Equatable {
    case liveSDK
    case stub
}

public enum AdConfiguration {
    /// config-svc Feature Flag；`enabled: false` 强制 stub，`true` 强制 live SDK。
    public static let liveSDKFeatureFlagKey = "ads.live_sdk"

    public static let infoPlistUseLiveSDKKey = "AdsUseLiveSDK"

    public static func useLiveSDKFromInfoPlist(bundle: Bundle = .main) -> Bool {
        guard let raw = bundle.infoDictionary?[infoPlistUseLiveSDKKey] as? String else {
            return false
        }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty || normalized.hasPrefix("$(") {
            return false
        }
        switch normalized {
        case "yes", "1", "true":
            return true
        case "no", "0", "false":
            return false
        default:
            return false
        }
    }

    /// Feature Flag 覆盖：nil 表示未下发，沿用编译条件。
    public static func resolveBackendMode(
        useLiveSDKFromInfoPlist: Bool? = nil,
        featureFlagEnabled: Bool? = nil,
        forceStub: Bool = false
    ) -> AdBackendMode {
        if forceStub {
            return .stub
        }
        if let featureFlagEnabled {
            return featureFlagEnabled ? .liveSDK : .stub
        }
        let useLiveSDK = useLiveSDKFromInfoPlist ?? Self.useLiveSDKFromInfoPlist()
        return useLiveSDK ? .liveSDK : .stub
    }
}
