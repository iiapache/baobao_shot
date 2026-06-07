import Foundation

/// App Attest keyId 持久化（同一设备复用密钥）。
public protocol AppAttestKeyStoring: Sendable {
    func loadKeyId() -> String?
    func saveKeyId(_ keyId: String)
    func isKeyAttested(_ keyId: String) -> Bool
    func markKeyAttested(_ keyId: String)
}

public final class AppAttestKeyStore: AppAttestKeyStoring, @unchecked Sendable {
    public static let shared = AppAttestKeyStore()

    private let defaults: UserDefaults
    private let keyIdKey = "com.babycamera.appAttest.keyId"
    private let attestedPrefix = "com.babycamera.appAttest.attested."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadKeyId() -> String? {
        defaults.string(forKey: keyIdKey)
    }

    public func saveKeyId(_ keyId: String) {
        defaults.set(keyId, forKey: keyIdKey)
    }

    public func isKeyAttested(_ keyId: String) -> Bool {
        defaults.bool(forKey: attestedPrefix + keyId)
    }

    public func markKeyAttested(_ keyId: String) {
        defaults.set(true, forKey: attestedPrefix + keyId)
    }
}
