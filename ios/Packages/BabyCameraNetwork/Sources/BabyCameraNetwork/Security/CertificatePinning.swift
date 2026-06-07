import CryptoKit
import Foundation
import Security

/// 证书绑定配置（T7.8 stub）：生产环境通过 SPKI 哈希列表开启，Debug 默认关闭。
public struct CertificatePinningConfiguration: Sendable, Equatable {
    public let isEnabled: Bool
    /// 主机 → Base64 编码的公钥 SHA-256 哈希（SPKI stub）
    public let pinnedHashesByHost: [String: Set<String>]

    public init(isEnabled: Bool, pinnedHashesByHost: [String: Set<String>] = [:]) {
        self.isEnabled = isEnabled
        self.pinnedHashesByHost = pinnedHashesByHost
    }

    /// Debug / 单测默认关闭；Release 由运维配置后显式开启。
    public static let `default` = CertificatePinningConfiguration(isEnabled: false)

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

/// URLSession 证书绑定委托（stub：开关关闭时走系统默认信任链）。
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
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }
        let digest = SHA256.hash(data: publicKeyData)
        return Data(digest).base64EncodedString()
    }
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
