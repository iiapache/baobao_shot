import CryptoKit
import Foundation

/// 阿里云 OSS REST 签名 V1（STS 临时凭据）
enum OSSRequestSigner {
    static func signedHeaders(
        method: String,
        bucket: String,
        objectKey: String,
        queryItems: [URLQueryItem] = [],
        contentType: String? = nil,
        contentMD5: String? = nil,
        extraHeaders: [String: String] = [:],
        credentials: STSCredentials
    ) -> [String: String] {
        let date = ossDateString()
        var headers = extraHeaders
        headers["Date"] = date
        headers["x-oss-security-token"] = credentials.securityToken
        if let contentType, !contentType.isEmpty {
            headers["Content-Type"] = contentType
        }
        if let contentMD5, !contentMD5.isEmpty {
            headers["Content-MD5"] = contentMD5
        }

        let resource = canonicalizedResource(bucket: bucket, objectKey: objectKey, queryItems: queryItems)
        let stringToSign = buildStringToSign(
            method: method,
            contentMD5: headers["Content-MD5"] ?? "",
            contentType: headers["Content-Type"] ?? "",
            date: date,
            ossHeaders: headers,
            resource: resource
        )
        let signature = hmacSHA1Base64(stringToSign, secret: credentials.accessKeySecret)
        headers["Authorization"] = "OSS \(credentials.accessKeyId):\(signature)"
        return headers
    }

    static func ossDateString(from date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter.string(from: date)
    }

    private static func buildStringToSign(
        method: String,
        contentMD5: String,
        contentType: String,
        date: String,
        ossHeaders: [String: String],
        resource: String
    ) -> String {
        let canonicalOSS = ossHeaders
            .filter { $0.key.lowercased().hasPrefix("x-oss-") }
            .sorted { $0.key.lowercased() < $1.key.lowercased() }
            .map { key, value in
                "\(key.lowercased()):\(value.trimmingCharacters(in: .whitespaces))"
            }
            .joined(separator: "\n")

        if canonicalOSS.isEmpty {
            return "\(method)\n\(contentMD5)\n\(contentType)\n\(date)\n\(resource)"
        }
        return "\(method)\n\(contentMD5)\n\(contentType)\n\(date)\n\(canonicalOSS)\n\(resource)"
    }

    private static func canonicalizedResource(
        bucket: String,
        objectKey: String,
        queryItems: [URLQueryItem]
    ) -> String {
        var resource = "/\(bucket)/\(objectKey)"
        let subResources = queryItems
            .sorted { ($0.name, $0.value ?? "") < ($1.name, $1.value ?? "") }
            .map { item in
                if let value = item.value, !value.isEmpty {
                    return "\(item.name)=\(value)"
                }
                return item.name
            }
        if !subResources.isEmpty {
            resource += "?" + subResources.joined(separator: "&")
        }
        return resource
    }

    private static func hmacSHA1Base64(_ message: String, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<Insecure.SHA1>.authenticationCode(for: Data(message.utf8), using: key)
        return Data(signature).base64EncodedString()
    }
}
