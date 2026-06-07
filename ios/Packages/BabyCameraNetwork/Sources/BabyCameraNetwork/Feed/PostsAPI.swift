import Foundation

// MARK: - Models

public enum PostVisibility: String, Codable, Sendable, CaseIterable {
    case family
    case selfOnly = "self"
}

public enum PostItemKind: String, Codable, Sendable, CaseIterable {
    case image
    case video
}

public struct PostCreateItem: Encodable, Sendable, Equatable {
    public let kind: PostItemKind
    public let objectKey: String
    public let width: Int
    public let height: Int
    public let deepSynth: Bool

    public init(
        kind: PostItemKind,
        objectKey: String,
        width: Int,
        height: Int,
        deepSynth: Bool
    ) {
        self.kind = kind
        self.objectKey = objectKey
        self.width = width
        self.height = height
        self.deepSynth = deepSynth
    }
}

public struct PostCreateRequest: Encodable, Sendable, Equatable {
    public let familyId: String
    public let babyIds: [String]
    public let caption: String
    public let visibility: PostVisibility
    public let items: [PostCreateItem]

    public init(
        familyId: String,
        babyIds: [String],
        caption: String,
        visibility: PostVisibility,
        items: [PostCreateItem]
    ) {
        self.familyId = familyId
        self.babyIds = babyIds
        self.caption = caption
        self.visibility = visibility
        self.items = items
    }
}

public struct PostCreateData: Decodable, Sendable, Equatable {
    public let postId: String
    public let status: String
    public let createdAt: String

    public init(postId: String, status: String, createdAt: String) {
        self.postId = postId
        self.status = status
        self.createdAt = createdAt
    }
}

public struct PostDeleteData: Decodable, Sendable, Equatable {
    public let postId: String
    public let status: String
    public let deletedAt: String

    public init(postId: String, status: String, deletedAt: String) {
        self.postId = postId
        self.status = status
        self.deletedAt = deletedAt
    }
}

// MARK: - Endpoint

enum PostsEndpoint: Endpoint {
    case create(PostCreateRequest)
    case delete(postId: String)

    var path: String {
        switch self {
        case .create:
            return "/v1/posts"
        case let .delete(postId):
            return "/v1/posts/\(postId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .create:
            return .post
        case .delete:
            return .delete
        }
    }

    func encodeBody(with encoder: JSONEncoder) throws -> Data? {
        switch self {
        case let .create(request):
            return try encoder.encode(request)
        case .delete:
            return nil
        }
    }
}

// MARK: - API

public struct PostsAPI: Sendable {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /v1/posts
    public func create(_ request: PostCreateRequest) async throws -> PostCreateData {
        try await client.request(PostsEndpoint.create(request))
    }

    /// DELETE /v1/posts/{postId} — 撤回已发布动态
    public func delete(postId: String) async throws -> PostDeleteData {
        try await client.request(PostsEndpoint.delete(postId: postId))
    }
}
