import Foundation

/// IAP / 订阅校验请求附带的 App Attest 字段（OPT-02）。
public struct AppAttestPayload: Encodable, Sendable, Equatable {
    public let keyId: String
    public let assertion: String
    public let clientDataHash: String

    public init(keyId: String, assertion: String, clientDataHash: String) {
        self.keyId = keyId
        self.assertion = assertion
        self.clientDataHash = clientDataHash
    }
}

public extension AppAttestPayload {
    init(attachment: AppAttestNetworkAttachment) {
        self.init(
            keyId: attachment.keyId,
            assertion: attachment.assertionBase64,
            clientDataHash: attachment.clientDataHashBase64
        )
    }
}

/// 跨模块桥接类型（Account → Network），避免 Network 依赖 Account。
public struct AppAttestNetworkAttachment: Sendable, Equatable {
    public let keyId: String
    public let assertionBase64: String
    public let clientDataHashBase64: String

    public init(keyId: String, assertionBase64: String, clientDataHashBase64: String) {
        self.keyId = keyId
        self.assertionBase64 = assertionBase64
        self.clientDataHashBase64 = clientDataHashBase64
    }
}

public typealias AppAttestAttachmentProvider = @Sendable (
    _ transactionId: String,
    _ productId: String
) async -> AppAttestNetworkAttachment?
