import Foundation

public struct APIEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    public let code: String
    public let message: String?
    public let requestId: String?
    public let data: T?

    public init(code: String, message: String?, requestId: String?, data: T?) {
        self.code = code
        self.message = message
        self.requestId = requestId
        self.data = data
    }
}

public struct EmptyData: Decodable, Sendable, Encodable {
    public init() {}
}
