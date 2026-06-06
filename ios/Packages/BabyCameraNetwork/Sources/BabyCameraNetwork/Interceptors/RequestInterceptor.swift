import Foundation

public protocol RequestInterceptor: Sendable {
    func intercept(_ request: URLRequest) async throws -> URLRequest
}

public protocol ResponseInterceptor: Sendable {
    func intercept(
        _ response: HTTPURLResponse,
        data: Data,
        request: URLRequest
    ) async throws
}
