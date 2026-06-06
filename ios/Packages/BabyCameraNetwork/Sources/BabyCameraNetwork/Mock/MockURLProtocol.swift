import Foundation

final class MockRegistry: @unchecked Sendable {
    static let shared = MockRegistry()
    private let lock = NSLock()
    private var handler: MockRequestHandler?
    private var requestLog: [URLRequest] = []

    func register(handler: @escaping MockRequestHandler) {
        lock.lock()
        defer { lock.unlock() }
        self.handler = handler
        requestLog.removeAll()
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        handler = nil
        requestLog.removeAll()
    }

    func recordedRequests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requestLog
    }

    func handle(_ request: URLRequest) -> MockResponse? {
        lock.lock()
        requestLog.append(request)
        let currentHandler = handler
        lock.unlock()
        return currentHandler?(request)
    }
}

public struct MockResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    public init(statusCode: Int, headers: [String: String] = [:], json: String) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = Data(json.utf8)
    }
}

public typealias MockRequestHandler = @Sendable (URLRequest) -> MockResponse?

public enum MockURLProtocol {
    public static func register(handler: @escaping MockRequestHandler) {
        MockRegistry.shared.register(handler: handler)
    }

    public static func reset() {
        MockRegistry.shared.reset()
    }

    public static func recordedRequests() -> [URLRequest] {
        MockRegistry.shared.recordedRequests()
    }

    public static func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocolHandler.self]
        return configuration
    }

    public static func makeSession() -> URLSession {
        URLSession(configuration: makeSessionConfiguration())
    }
}

private final class MockURLProtocolHandler: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let response = MockRegistry.shared.handle(request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: response.headers
        )!

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

public enum MockServer {
    public static func loginSuccessJSON(
        userId: String = "usr_test_001",
        accessToken: String = "access_token_initial",
        refreshToken: String = "refresh_token_initial"
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_login_001",
          "data": {
            "userId": "\(userId)",
            "isNewUser": true,
            "accessToken": "\(accessToken)",
            "accessTokenExpiresIn": 3600,
            "refreshToken": "\(refreshToken)",
            "refreshTokenExpiresIn": 2592000,
            "profile": {
              "nickname": "测试用户",
              "avatarUrl": null,
              "region": "cn",
              "consents": { "childData": false }
            }
          }
        }
        """
    }

    public static func refreshSuccessJSON(
        accessToken: String = "access_token_refreshed",
        refreshToken: String = "refresh_token_rotated"
    ) -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_refresh_001",
          "data": {
            "accessToken": "\(accessToken)",
            "accessTokenExpiresIn": 3600,
            "refreshToken": "\(refreshToken)",
            "refreshTokenExpiresIn": 2592000
          }
        }
        """
    }

    public static func tokenExpiredJSON() -> String {
        """
        {
          "code": "AUTH_TOKEN_EXPIRED",
          "message": "access token expired",
          "requestId": "req_expired_001"
        }
        """
    }

    public static func meSuccessJSON(userId: String = "usr_test_001") -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_me_001",
          "data": {
            "userId": "\(userId)",
            "nickname": "测试用户",
            "avatarUrl": null,
            "region": "cn",
            "consents": { "childData": false }
          }
        }
        """
    }

    public static func emptySuccessJSON(requestId: String = "req_ok_001") -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "\(requestId)"
        }
        """
    }

    public static func deletionSuccessJSON() -> String {
        """
        {
          "code": "OK",
          "message": "ok",
          "requestId": "req_delete_001",
          "data": {
            "requestedAt": "2026-06-06T10:00:00Z",
            "scheduledAt": "2026-06-13T10:00:00Z",
            "revokeBefore": "2026-06-13T10:00:00Z"
          }
        }
        """
    }
}
