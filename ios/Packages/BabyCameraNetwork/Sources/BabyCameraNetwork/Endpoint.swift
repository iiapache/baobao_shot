import Foundation

public enum AuthRequirement: Sendable {
    case none
    case required
}

public protocol Endpoint: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var authRequirement: AuthRequirement { get }
    var queryItems: [URLQueryItem]? { get }
    var headers: [String: String]? { get }
    func encodeBody(with encoder: JSONEncoder) throws -> Data?
}

public extension Endpoint {
    var authRequirement: AuthRequirement { .required }
    var queryItems: [URLQueryItem]? { nil }
    var headers: [String: String]? { nil }

    func encodeBody(with encoder: JSONEncoder) throws -> Data? { nil }
}

public struct AnyEncodableEndpoint: Endpoint {
    public let path: String
    public let method: HTTPMethod
    public let authRequirement: AuthRequirement
    public let queryItems: [URLQueryItem]?
    public let headers: [String: String]?
    private let bodyProvider: @Sendable (JSONEncoder) throws -> Data?

    public init(
        path: String,
        method: HTTPMethod,
        authRequirement: AuthRequirement = .required,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String]? = nil,
        body: (any Encodable & Sendable)? = nil
    ) {
        self.path = path
        self.method = method
        self.authRequirement = authRequirement
        self.queryItems = queryItems
        self.headers = headers
        if let body {
            let captured = body
            self.bodyProvider = { encoder in try encoder.encode(captured) }
        } else {
            self.bodyProvider = { _ in nil }
        }
    }

    public func encodeBody(with encoder: JSONEncoder) throws -> Data? {
        try bodyProvider(encoder)
    }
}
