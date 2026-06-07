import CoreImage
import CryptoKit
import Foundation
import UIKit

public enum InvitationCodeServiceError: Error, Equatable, Sendable {
    case invalidPayload
    case invalidSignature
    case qrGenerationFailed
}

/// 邀请码二维码编解码 — HMAC 格式与 auth-family-svc invite_sign.go 对齐
public struct InvitationCodeService: Sendable {
    public static let defaultAppScheme = "baobao://invite"

    private let signingSecret: String?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(signingSecret: String? = nil) {
        self.signingSecret = signingSecret
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - HMAC

    /// 与后端 `signInviteCode` 一致：HMAC-SHA256(code) → hex
    public static func signInviteCode(_ code: String, signingSecret: String) -> String {
        let key = SymmetricKey(data: Data(signingSecret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(code.utf8), using: key)
        return signature.map { String(format: "%02x", $0) }.joined()
    }

    public func verifyPayload(_ payload: InviteQRPayload) -> Bool {
        guard !payload.sig.isEmpty else { return true }
        guard let secret = signingSecret, !secret.isEmpty else {
            return true
        }
        let expected = Self.signInviteCode(payload.code, signingSecret: secret)
        return constantTimeCompare(expected, payload.sig)
    }

    public func signPayload(code: String, appScheme: String = defaultAppScheme) -> InviteQRPayload? {
        guard let secret = signingSecret, !secret.isEmpty else { return nil }
        return InviteQRPayload(
            scheme: appScheme,
            code: code,
            sig: Self.signInviteCode(code, signingSecret: secret)
        )
    }

    // MARK: - Serialization

    public func encodePayload(_ payload: InviteQRPayload) throws -> String {
        let data = try encoder.encode(payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw InvitationCodeServiceError.invalidPayload
        }
        return json
    }

    public func decodePayload(from scanned: String) throws -> InviteQRPayload {
        let trimmed = scanned.trimmingCharacters(in: .whitespacesAndNewlines)

        if let payload = try? decodeJSONPayload(trimmed) {
            guard verifyPayload(payload) else {
                throw InvitationCodeServiceError.invalidSignature
            }
            return payload
        }

        if let payload = try? decodeDeepLink(trimmed) {
            guard verifyPayload(payload) else {
                throw InvitationCodeServiceError.invalidSignature
            }
            return payload
        }

        if isPlainInviteCode(trimmed) {
            return InviteQRPayload(scheme: Self.defaultAppScheme, code: trimmed, sig: "")
        }

        throw InvitationCodeServiceError.invalidPayload
    }

    public func extractInviteCode(from scanned: String) throws -> String {
        try decodePayload(from: scanned).code
    }

    // MARK: - QR Image

    public func generateQRImage(from payload: InviteQRPayload, scale: CGFloat = 10) throws -> UIImage {
        let json = try encodePayload(payload)
        return try generateQRImage(fromString: json, scale: scale)
    }

    public func generateQRImage(fromString content: String, scale: CGFloat = 10) throws -> UIImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(content.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            throw InvitationCodeServiceError.qrGenerationFailed
        }

        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            throw InvitationCodeServiceError.qrGenerationFailed
        }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Clipboard

    public func copyInviteCodeToClipboard(_ code: String) {
        UIPasteboard.general.string = code
    }

    // MARK: - Private

    private func decodeJSONPayload(_ string: String) throws -> InviteQRPayload {
        guard let data = string.data(using: .utf8) else {
            throw InvitationCodeServiceError.invalidPayload
        }
        return try decoder.decode(InviteQRPayload.self, from: data)
    }

    private func decodeDeepLink(_ string: String) throws -> InviteQRPayload {
        guard let url = URL(string: string),
              url.scheme?.hasPrefix("baobao") == true || string.hasPrefix(Self.defaultAppScheme) else {
            throw InvitationCodeServiceError.invalidPayload
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw InvitationCodeServiceError.invalidPayload
        }

        let queryItems = components.queryItems ?? []
        func value(_ name: String) -> String? {
            queryItems.first(where: { $0.name == name })?.value
        }

        if let code = value("code"), let sig = value("sig") {
            return InviteQRPayload(
                scheme: Self.defaultAppScheme,
                code: code,
                sig: sig
            )
        }

        throw InvitationCodeServiceError.invalidPayload
    }

    private func isPlainInviteCode(_ string: String) -> Bool {
        string.count == 6 && string.allSatisfy(\.isNumber)
    }

    private func constantTimeCompare(_ lhs: String, _ rhs: String) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var diff: UInt8 = 0
        for (a, b) in zip(lhs.utf8, rhs.utf8) {
            diff |= a ^ b
        }
        return diff == 0
    }
}
