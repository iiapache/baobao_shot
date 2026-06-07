import BabyCameraNetwork
import Foundation

/// 端侧同意版本校验：与后端 `child_consent_v1` 对齐，版本不匹配时强制重新同意。
public enum ConsentVersionChecker {
    private static let storageKeyPrefix = "childDataConsentVersion."

    public static let currentVersion = ChildDataConsent.currentVersion

    public static func recordAgreedVersion(_ version: String, userId: String) {
        UserDefaults.standard.set(version, forKey: storageKey(for: userId))
    }

    public static func agreedVersion(for userId: String) -> String? {
        UserDefaults.standard.string(forKey: storageKey(for: userId))
    }

    public static func clearAgreedVersion(for userId: String) {
        UserDefaults.standard.removeObject(forKey: storageKey(for: userId))
    }

    /// 服务端已同意且本地记录版本与当前文档一致。
    public static func hasValidConsent(userId: String?, profile: UserProfile?) -> Bool {
        guard let userId, let profile else { return false }
        guard ChildDataConsent.hasServerConsent(in: profile) else { return false }
        guard let localVersion = agreedVersion(for: userId) else { return false }
        return localVersion == currentVersion
    }

    /// 版本升级或从未同意时需要重新走同意流程。
    public static func requiresReconsent(userId: String?, profile: UserProfile?) -> Bool {
        !hasValidConsent(userId: userId, profile: profile)
    }

    private static func storageKey(for userId: String) -> String {
        storageKeyPrefix + userId
    }
}
