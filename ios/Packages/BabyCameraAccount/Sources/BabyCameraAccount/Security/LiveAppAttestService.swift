import Foundation
#if canImport(DeviceCheck)
import DeviceCheck
#endif

/// App Attest 真实实现：iOS 14+ DCAppAttestService。
public final class LiveAppAttestService: AppAttestProviding, @unchecked Sendable {
    public init() {}

    public var isSupported: Bool {
        if #available(iOS 14.0, *) {
            return LiveAppAttestServiceCore.isSupported
        }
        return false
    }

    public func generateKey() async throws -> String {
        if #available(iOS 14.0, *) {
            return try await LiveAppAttestServiceCore.generateKey()
        }
        throw AppAttestError.notSupported
    }

    public func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        if #available(iOS 14.0, *) {
            return try await LiveAppAttestServiceCore.attestKey(keyId, clientDataHash: clientDataHash)
        }
        throw AppAttestError.notSupported
    }

    public func generateAssertion(keyId: String, clientDataHash: Data) async throws -> Data {
        if #available(iOS 14.0, *) {
            return try await LiveAppAttestServiceCore.generateAssertion(
                keyId: keyId,
                clientDataHash: clientDataHash
            )
        }
        throw AppAttestError.notSupported
    }
}

@available(iOS 14.0, *)
private enum LiveAppAttestServiceCore {
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
