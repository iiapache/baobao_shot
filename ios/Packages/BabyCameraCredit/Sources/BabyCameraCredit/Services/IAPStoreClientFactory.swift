import Foundation

/// IAP 后端模式：StoreKit 2 沙盒/生产，或本地 stub（mock JWS）。
public enum IAPBackendMode: String, Sendable, Equatable {
    case storeKit
    case stub
}

public enum IAPConfiguration {
    /// config-svc Feature Flag，与 `iap.os_storekit2` 同义；端侧优先读此键。
    public static let storeKitFeatureFlagKey = "iap.storekit2"
    public static let legacyOSStoreKitFeatureFlagKey = "iap.os_storekit2"
    public static let infoPlistUseStoreKitKey = "IAPUseStoreKit"

    /// 从 Info.plist（xcconfig → build setting）读取是否启用 StoreKit。
    public static func useStoreKitFromInfoPlist(bundle: Bundle = .main) -> Bool {
        guard let raw = bundle.infoDictionary?[infoPlistUseStoreKitKey] as? String else {
            return true
        }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty || normalized.hasPrefix("$(") {
            return true
        }
        switch normalized {
        case "yes", "1", "true":
            return true
        case "no", "0", "false":
            return false
        default:
            return true
        }
    }

    /// Feature Flag 覆盖：nil 表示未下发，沿用编译条件。
    public static func resolveBackendMode(
        useStoreKitFromInfoPlist: Bool? = nil,
        featureFlagEnabled: Bool? = nil,
        forceStub: Bool = false
    ) -> IAPBackendMode {
        if forceStub {
            return .stub
        }
        if let featureFlagEnabled {
            return featureFlagEnabled ? .storeKit : .stub
        }
        let useStoreKit = useStoreKitFromInfoPlist ?? Self.useStoreKitFromInfoPlist()
        return useStoreKit ? .storeKit : .stub
    }
}

public enum IAPStoreClientFactory {
    public static func make(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        featureFlagEnabled: Bool? = nil,
        useStoreKitOverride: Bool? = nil
    ) -> IAPStoreClient {
        let mode = IAPConfiguration.resolveBackendMode(
            useStoreKitFromInfoPlist: useStoreKitOverride,
            featureFlagEnabled: featureFlagEnabled,
            forceStub: forceStub
        )
        switch mode {
        case .storeKit:
            return StoreKitPurchaseClient()
        case .stub:
            return StubIAPStoreClient()
        }
    }

    /// 读取当前模式，便于 Debug 菜单或日志。
    public static func currentMode(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        featureFlagEnabled: Bool? = nil
    ) -> IAPBackendMode {
        IAPConfiguration.resolveBackendMode(
            useStoreKitFromInfoPlist: IAPConfiguration.useStoreKitFromInfoPlist(bundle: bundle),
            featureFlagEnabled: featureFlagEnabled,
            forceStub: forceStub
        )
    }
}
