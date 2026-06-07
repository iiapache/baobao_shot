import CryptoKit
import Foundation

/// App Attest 编译开关 + Info.plist 解析（OPT-02）。
public enum AppAttestConfigurationFactory {
    public static let infoPlistEnabledKey = "AppAttestEnabled"
    public static let environmentEnabledKey = "APP_ATTEST_ENABLED"

    /// 单测 / UITest 强制 stub。
    public static func resolve(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        enabledOverride: Bool? = nil,
        infoDictionary: [String: Any]? = nil
    ) -> AppAttestProviding {
        if forceStub {
            return StubAppAttestService()
        }

        let info = infoDictionary ?? bundle.infoDictionary ?? [:]
        let enabled = enabledOverride ?? resolveEnabled(from: info)
        if enabled {
            return LiveAppAttestService()
        }
        return StubAppAttestService()
    }

    public static func resolveEnabled(from bundle: Bundle = .main) -> Bool {
        resolveEnabled(from: bundle.infoDictionary ?? [:])
    }

    static func resolveEnabled(from info: [String: Any]) -> Bool {
        if let env = ProcessInfo.processInfo.environment[environmentEnabledKey] {
            let normalized = env.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "1" || normalized == "true" || normalized == "yes"
        }
        return parseBooleanPlistValue(info[infoPlistEnabledKey])
    }

    static func parseBooleanPlistValue(_ value: Any?) -> Bool {
        if let bool = value as? Bool {
            return bool
        }
        guard let raw = value as? String else { return false }
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
}

/// IAP / 订阅校验附带的 App Attest Assertion。
public struct AppAttestIAPAttachment: Sendable, Equatable {
    public let keyId: String
    public let assertionBase64: String
    public let clientDataHashBase64: String

    public init(keyId: String, assertionBase64: String, clientDataHashBase64: String) {
        self.keyId = keyId
        self.assertionBase64 = assertionBase64
        self.clientDataHashBase64 = clientDataHashBase64
    }
}

/// 为 IAP 请求生成 App Attest Assertion（clientDataHash = SHA256(transactionId:productId)）。
public struct AppAttestIAPAttachmentBuilder: Sendable {
    private let service: AppAttestProviding
    private let keyStore: AppAttestKeyStoring

    public init(
        service: AppAttestProviding = AppAttestService.shared,
        keyStore: AppAttestKeyStoring = AppAttestKeyStore.shared
    ) {
        self.service = service
        self.keyStore = keyStore
    }

    /// 开关关闭或不支持时返回 `nil`，不阻塞 IAP 上送。
    public func attachment(
        transactionId: String,
        productId: String
    ) async -> AppAttestIAPAttachment? {
        guard service.isSupported else { return nil }

        let clientDataHash = Self.clientDataHash(transactionId: transactionId, productId: productId)

        do {
            let keyId = try await resolveKeyId()
            if !keyStore.isKeyAttested(keyId) {
                _ = try await service.attestKey(keyId, clientDataHash: clientDataHash)
                keyStore.markKeyAttested(keyId)
            }
            let assertion = try await service.generateAssertion(
                keyId: keyId,
                clientDataHash: clientDataHash
            )
            return AppAttestIAPAttachment(
                keyId: keyId,
                assertionBase64: assertion.base64EncodedString(),
                clientDataHashBase64: clientDataHash.base64EncodedString()
            )
        } catch {
            return nil
        }
    }

    static func clientDataHash(transactionId: String, productId: String) -> Data {
        let challenge = "\(transactionId):\(productId)"
        let digest = SHA256.hash(data: Data(challenge.utf8))
        return Data(digest)
    }

    private func resolveKeyId() async throws -> String {
        if let existing = keyStore.loadKeyId() {
            return existing
        }
        let keyId = try await service.generateKey()
        keyStore.saveKeyId(keyId)
        return keyId
    }
}
