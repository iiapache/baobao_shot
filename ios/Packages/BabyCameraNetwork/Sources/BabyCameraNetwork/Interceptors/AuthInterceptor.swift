import Foundation

public final class AuthInterceptor: RequestInterceptor, @unchecked Sendable {
    private let tokenStore: TokenStore

    public init(tokenStore: TokenStore) {
        self.tokenStore = tokenStore
    }

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        if let token = tokenStore.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
