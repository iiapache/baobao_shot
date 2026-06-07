import Foundation

/// App Attest stub：开关关闭 / 单测 / 模拟器路径，不调用 DeviceCheck。
public final class StubAppAttestService: AppAttestProviding, @unchecked Sendable {
    public init() {}

    public var isSupported: Bool { false }

    public func generateKey() async throws -> String {
        throw AppAttestError.disabled
    }

    public func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        throw AppAttestError.disabled
    }

    public func generateAssertion(keyId: String, clientDataHash: Data) async throws -> Data {
        throw AppAttestError.disabled
    }
}
