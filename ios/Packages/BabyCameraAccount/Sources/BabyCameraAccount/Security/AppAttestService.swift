import Foundation
#if canImport(DeviceCheck)
import DeviceCheck
#endif

/// App Attest 开关（T7.8 stub）：默认关闭，TestFlight / 生产由运维或 Info.plist 开启。
public enum AppAttestConfiguration: Sendable {
    public static var isEnabled: Bool {
        if let env = ProcessInfo.processInfo.environment["APP_ATTEST_ENABLED"] {
            return env == "1" || env.lowercased() == "true"
        }
        return Bundle.main.object(forInfoDictionaryKey: "AppAttestEnabled") as? Bool ?? false
    }
}

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

/// App Attest stub：iOS 14+ 可选，编译守卫；开关关闭时返回 `.disabled`。
public final class AppAttestService: AppAttestProviding, @unchecked Sendable {
    public static let shared = AppAttestService()

    private let isEnabled: Bool

    public init(isEnabled: Bool = AppAttestConfiguration.isEnabled) {
        self.isEnabled = isEnabled
    }

    public var isSupported: Bool {
        guard isEnabled else { return false }
        if #available(iOS 14.0, *) {
            return AppAttestServiceCore.isSupported
        }
        return false
    }

    public func generateKey() async throws -> String {
        guard isEnabled else { throw AppAttestError.disabled }
        if #available(iOS 14.0, *) {
            return try await AppAttestServiceCore.generateKey()
        }
        throw AppAttestError.notSupported
    }

    public func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        guard isEnabled else { throw AppAttestError.disabled }
        if #available(iOS 14.0, *) {
            return try await AppAttestServiceCore.attestKey(keyId, clientDataHash: clientDataHash)
        }
        throw AppAttestError.notSupported
    }

    public func generateAssertion(keyId: String, clientDataHash: Data) async throws -> Data {
        guard isEnabled else { throw AppAttestError.disabled }
        if #available(iOS 14.0, *) {
            return try await AppAttestServiceCore.generateAssertion(
                keyId: keyId,
                clientDataHash: clientDataHash
            )
        }
        throw AppAttestError.notSupported
    }
}

@available(iOS 14.0, *)
private enum AppAttestServiceCore {
    static var isSupported: Bool {
        #if canImport(DeviceCheck)
        DCAppAttestService.shared.isSupported
        #else
        false
        #endif
    }

    static func generateKey() async throws -> String {
        #if canImport(DeviceCheck)
        try await withCheckedThrowingContinuation { continuation in
            DCAppAttestService.shared.generateKey { keyId, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let keyId {
                    continuation.resume(returning: keyId)
                } else {
                    continuation.resume(throwing: AppAttestError.keyGenerationFailed)
                }
            }
        }
        #else
        throw AppAttestError.notSupported
        #endif
    }

    static func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        #if canImport(DeviceCheck)
        try await withCheckedThrowingContinuation { continuation in
            DCAppAttestService.shared.attestKey(keyId, clientDataHash: clientDataHash) { attestation, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let attestation {
                    continuation.resume(returning: attestation)
                } else {
                    continuation.resume(throwing: AppAttestError.attestationFailed)
                }
            }
        }
        #else
        throw AppAttestError.notSupported
        #endif
    }

    static func generateAssertion(keyId: String, clientDataHash: Data) async throws -> Data {
        #if canImport(DeviceCheck)
        try await withCheckedThrowingContinuation { continuation in
            DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: clientDataHash) { assertion, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let assertion {
                    continuation.resume(returning: assertion)
                } else {
                    continuation.resume(throwing: AppAttestError.assertionFailed)
                }
            }
        }
        #else
        throw AppAttestError.notSupported
        #endif
    }
}
