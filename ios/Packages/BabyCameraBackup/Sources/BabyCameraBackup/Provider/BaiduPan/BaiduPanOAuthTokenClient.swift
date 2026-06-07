import Foundation

public protocol BaiduPanOAuthTokenExchanging: Sendable {
    func exchangeAuthorizationCode(
        code: String,
        clientID: String,
        clientSecret: String,
        redirectURI: String
    ) async throws -> BaiduPanOAuthTokenResponse

    func fetchLoggedInUserID(accessToken: String) async throws -> String?
}

public struct BaiduPanOAuthTokenResponse: Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresIn: Int?
    public let scope: String?

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        expiresIn: Int? = nil,
        scope: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.scope = scope
    }
}

public struct URLSessionBaiduPanOAuthTokenClient: BaiduPanOAuthTokenExchanging, Sendable {
    private let transport: BaiduPanHTTPTransport

    public init(transport: BaiduPanHTTPTransport = URLSessionBaiduPanTransport()) {
        self.transport = transport
    }

    public func exchangeAuthorizationCode(
        code: String,
        clientID: String,
        clientSecret: String,
        redirectURI: String
    ) async throws -> BaiduPanOAuthTokenResponse {
        var request = URLRequest(url: BaiduPanOAuthConfiguration.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "grant_type=authorization_code",
            "code=\(code.urlFormEncoded)",
            "client_id=\(clientID.urlFormEncoded)",
            "client_secret=\(clientSecret.urlFormEncoded)",
            "redirect_uri=\(redirectURI.urlFormEncoded)",
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await transport.data(for: request)
        guard (200 ... 299).contains(response.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "token exchange failed"
            throw BaiduPanProviderError.authorizationFailed(message)
        }

        let payload = try JSONDecoder().decode(BaiduPanOAuthTokenPayload.self, from: data)
        if let error = payload.error, !error.isEmpty {
            throw BaiduPanProviderError.authorizationFailed(payload.errorDescription ?? error)
        }
        guard let accessToken = payload.accessToken, !accessToken.isEmpty else {
            throw BaiduPanProviderError.authorizationFailed("missing access_token")
        }
        return BaiduPanOAuthTokenResponse(
            accessToken: accessToken,
            refreshToken: payload.refreshToken,
            expiresIn: payload.expiresIn,
            scope: payload.scope
        )
    }

    public func fetchLoggedInUserID(accessToken: String) async throws -> String? {
        var components = URLComponents(url: BaiduPanOAuthConfiguration.loggedInUserURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "access_token", value: accessToken)]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await transport.data(for: request)
        guard (200 ... 299).contains(response.statusCode) else {
            return nil
        }
        let payload = try JSONDecoder().decode(BaiduPanLoggedInUserPayload.self, from: data)
        return payload.user?.uid.map(String.init)
    }
}

private struct BaiduPanOAuthTokenPayload: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let scope: String?
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
        case error
        case errorDescription = "error_description"
    }
}

private struct BaiduPanLoggedInUserPayload: Decodable {
    struct User: Decodable {
        let uid: Int64?
    }

    let user: User?
}

private extension String {
    var urlFormEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
