import Foundation

public enum AppAttestError: Error, Sendable, Equatable {
    case disabled
    case notSupported
    case keyGenerationFailed
    case attestationFailed
    case assertionFailed
}

/// App Attest 协议 — IAP / 订阅校验时附 Attestation（iOS 14+）。
public protocol AppAttestProviding: Sendable {
    var isSupported: Bool { get }
    func generateKey() async throws -> String
    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data
    func generateAssertion(keyId: String, clientDataHash: Data) async throws -> Data
}

/// App Attest 门面：按 OPT-02 配置解析 live / stub 实现。
public final class AppAttestService: AppAttestProviding, @unchecked Sendable {
    public static let shared = AppAttestService()

    private let backing: AppAttestProviding

    public init(
        isEnabled: Bool? = nil,
        forceStub: Bool = false,
        backing: AppAttestProviding? = nil
    ) {
        if let backing {
            self.backing = backing
        } else if forceStub || isEnabled == false {
            self.backing = StubAppAttestService()
        } else if isEnabled == true {
            self.backing = LiveAppAttestService()
        } else {
            self.backing = AppAttestConfigurationFactory.resolve(forceStub: forceStub)
        }
    }

    public var isSupported: Bool {
        backing.isSupported
    }

    public func generateKey() async throws -> String {
        try await backing.generateKey()
    }

    public func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        try await backing.attestKey(keyId, clientDataHash: clientDataHash)
    }

    public func generateAssertion(keyId: String, clientDataHash: Data) async throws -> Data {
        try await backing.generateAssertion(keyId: keyId, clientDataHash: clientDataHash)
    }
}

/// 向后兼容：`AppAttestConfiguration.isEnabled` 读取 plist / 环境变量。
public enum AppAttestConfiguration: Sendable {
    public static var isEnabled: Bool {
        AppAttestConfigurationFactory.resolveEnabled()
    }
}
