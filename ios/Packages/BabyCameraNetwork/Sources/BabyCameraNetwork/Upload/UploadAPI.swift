import Foundation

enum UploadEndpoint: Endpoint {
    case initUpload(UploadInitRequest)
    case complete(UploadCompleteRequest)

    var path: String {
        switch self {
        case .initUpload:
            return "/v1/uploads/init"
        case .complete:
            return "/v1/uploads/complete"
        }
    }

    var method: HTTPMethod {
        .post
    }

    var headers: [String: String]? {
        ["Content-Type": "application/json; charset=utf-8"]
    }

    func encodeBody(with encoder: JSONEncoder) throws -> Data? {
        switch self {
        case let .initUpload(body):
            return try encoder.encode(body)
        case let .complete(body):
            return try encoder.encode(body)
        }
    }
}

/// media-svc 上传 init / complete API
public struct UploadAPI: Sendable {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /v1/uploads/init
    public func initialize(_ request: UploadInitRequest) async throws -> UploadInitData {
        try await client.request(UploadEndpoint.initUpload(request))
    }

    /// POST /v1/uploads/complete
    public func complete(_ request: UploadCompleteRequest) async throws -> UploadCompleteData {
        try await client.request(UploadEndpoint.complete(request))
    }
}
