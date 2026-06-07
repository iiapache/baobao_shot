import CryptoKit
import Foundation
import Security

/// 证书绑定配置：生产环境通过 SPKI SHA-256（Base64）列表开启，Debug 默认关闭。
public struct CertificatePinningConfiguration: Sendable, Equatable {
    public let isEnabled: Bool
    /// 主机 → Base64 编码的 SPKI SHA-256 哈希
    public let pinnedHashesByHost: [String: Set<String>]

    public init(isEnabled: Bool, pinnedHashesByHost: [String: Set<String>] = [:]) {
        self.isEnabled = isEnabled
        self.pinnedHashesByHost = pinnedHashesByHost
    }

    /// 单测 / 未注入编译开关时的默认：关闭（stub 路径）。
    public static let `default` = CertificatePinningConfiguration(isEnabled: false)

    /// 显式关闭证书绑定（系统默认 TLS）。
    public static let disabled = CertificatePinningConfiguration(isEnabled: false)

    public func pinnedHashes(for host: String) -> Set<String> {
        pinnedHashesByHost[host] ?? []
    }
}

public enum CertificatePinningError: Error, Sendable, Equatable {
    case disabled
    case hostNotPinned(host: String)
    case pinMismatch(host: String)
    case trustEvaluationFailed
}

/// URLSession 证书绑定委托：开关关闭时走系统默认信任链。
public final class CertificatePinningDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let configuration: CertificatePinningConfiguration

    public init(configuration: CertificatePinningConfiguration) {
        self.configuration = configuration
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard configuration.isEnabled else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let host = challenge.protectionSpace.host
        let expectedPins = configuration.pinnedHashes(for: host)
        guard !expectedPins.isEmpty else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        if CertificatePinningValidator.validate(
            serverTrust: serverTrust,
            expectedPins: expectedPins
        ) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

public enum CertificatePinningValidator {
    public static func validate(serverTrust: SecTrust, expectedPins: Set<String>) -> Bool {
        guard SecTrustEvaluateWithError(serverTrust, nil) else {
            return false
        }
        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            return false
        }
        for certificate in chain {
            if let hash = spkiHash(for: certificate),
               expectedPins.contains(hash) {
                return true
            }
        }
        return false
    }

    static func spkiHash(for certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let attributes = SecKeyCopyAttributes(publicKey) as? [String: Any],
              let keyType = attributes[kSecAttrKeyType as String] as? String,
              let keySize = attributes[kSecAttrKeySizeInBits as String] as? Int,
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?,
              let spkiPrefix = spkiPrefix(forKeyType: keyType, keySizeInBits: keySize) else {
            return nil
        }
        var spkiBytes = Data(spkiPrefix)
        spkiBytes.append(publicKeyData)
        let digest = SHA256.hash(data: spkiBytes)
        return Data(digest).base64EncodedString()
    }

    static func spkiPrefix(forKeyType keyType: String, keySizeInBits: Int) -> [UInt8]? {
        if keyType == (kSecAttrKeyTypeRSA as String), keySizeInBits == 2_048 {
            return rsa2048SPKIHeader
        }
        if keyType == (kSecAttrKeyTypeECSECPrimeRandom as String), keySizeInBits == 256 {
            return ecP256SPKIHeader
        }
        return nil
    }

    private static let rsa2048SPKIHeader: [UInt8] = [
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00,
        0x03, 0x82, 0x01, 0x0f, 0x00,
    ]

    private static let ecP256SPKIHeader: [UInt8] = [
        0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08,
        0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00,
    ]
}

public enum CertificatePinningSessionFactory {
    public static func makeSession(
        configuration: CertificatePinningConfiguration,
        sessionConfiguration: URLSessionConfiguration = .default
    ) -> URLSession {
        guard configuration.isEnabled else {
            return URLSession(configuration: sessionConfiguration)
        }
        let delegate = CertificatePinningDelegate(configuration: configuration)
        return URLSession(
            configuration: sessionConfiguration,
            delegate: delegate,
            delegateQueue: nil
        )
    }
}
