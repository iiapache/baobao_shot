import Foundation
import os.log

public protocol NetworkLogger: Sendable {
    func log(_ message: String)
}

public struct OSNetworkLogger: NetworkLogger {
    private let logger = Logger(subsystem: "com.babygrowth.network", category: "api")

    public init() {}

    public func log(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }
}

public enum LogRedactor {
    private static let bearerPattern = try! NSRegularExpression(
        pattern: #"Bearer\s+[A-Za-z0-9\-._~+/]+=*"#,
        options: [.caseInsensitive]
    )
    private static let authorizationPattern = try! NSRegularExpression(
        pattern: #"("accessToken"\s*:\s*")[^"]+(")"#,
        options: [.caseInsensitive]
    )
    private static let refreshTokenPattern = try! NSRegularExpression(
        pattern: #"("refreshToken"\s*:\s*")[^"]+(")"#,
        options: [.caseInsensitive]
    )
    private static let phonePattern = try! NSRegularExpression(
        pattern: #"(?<!\d)(1[3-9]\d{9})(?!\d)"#,
        options: []
    )
    private static let phoneFieldPattern = try! NSRegularExpression(
        pattern: #"("phone"\s*:\s*")[^"]+(")"#,
        options: [.caseInsensitive]
    )

    public static func redact(_ input: String) -> String {
        var result = input
        result = replaceMatches(in: result, pattern: bearerPattern, template: "Bearer [REDACTED]")
        result = replaceMatches(in: result, pattern: authorizationPattern, template: "$1[REDACTED]$2")
        result = replaceMatches(in: result, pattern: refreshTokenPattern, template: "$1[REDACTED]$2")
        result = replaceMatches(in: result, pattern: phoneFieldPattern, template: "$1[REDACTED]$2")
        result = replaceMatches(in: result, pattern: phonePattern, template: "[REDACTED_PHONE]")
        return result
    }

    private static func replaceMatches(
        in input: String,
        pattern: NSRegularExpression,
        template: String
    ) -> String {
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return pattern.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: template)
    }
}

public final class LoggingInterceptor: ResponseInterceptor, @unchecked Sendable {
    private let logger: NetworkLogger
    public private(set) var loggedMessages: [String] = []
    private let lock = NSLock()
    private let captureForTesting: Bool

    public init(logger: NetworkLogger = OSNetworkLogger(), captureForTesting: Bool = false) {
        self.logger = logger
        self.captureForTesting = captureForTesting
    }

    public func intercept(
        _ response: HTTPURLResponse,
        data: Data,
        request: URLRequest
    ) async throws {
        let method = request.httpMethod ?? "?"
        let path = request.url?.path ?? "?"
        let status = response.statusCode
        let body = String(data: data, encoding: .utf8) ?? "<binary>"
        let authHeader = request.value(forHTTPHeaderField: "Authorization") ?? ""
        let message = LogRedactor.redact(
            "[\(method)] \(path) status=\(status) auth=\(authHeader) body=\(body)"
        )
        logger.log(message)
        if captureForTesting {
            lock.lock()
            loggedMessages.append(message)
            lock.unlock()
        }
    }

    public func capturedMessages() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return loggedMessages
    }
}
