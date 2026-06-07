import Foundation

// MARK: - Models

public struct FeedMediaItem: Decodable, Sendable, Equatable, Identifiable {
    public var id: String { itemId }

    public let itemId: String
    public let kind: String
    public let objectKey: String
    public let mime: String?
    public let width: Int
    public let height: Int
    public let duration: Int?
    public let deepSynth: Bool
    public let thumbnailKey: String?

    public init(
        itemId: String,
        kind: String,
        objectKey: String,
        mime: String? = nil,
        width: Int,
        height: Int,
        duration: Int? = nil,
        deepSynth: Bool,
        thumbnailKey: String? = nil
    ) {
        self.itemId = itemId
        self.kind = kind
        self.objectKey = objectKey
        self.mime = mime
        self.width = width
        self.height = height
        self.duration = duration
        self.deepSynth = deepSynth
        self.thumbnailKey = thumbnailKey
    }
}

public struct FeedPostItem: Decodable, Sendable, Equatable, Identifiable {
    public var id: String { postId }

    public let postId: String
    public let familyId: String
    public let ownerUserId: String
    public let babyIds: [String]
    public let caption: String
    public let visibility: String
    public let status: String
    public let createdAt: String
    public let items: [FeedMediaItem]

    public init(
        postId: String,
        familyId: String,
        ownerUserId: String,
        babyIds: [String],
        caption: String,
        visibility: String,
        status: String,
        createdAt: String,
        items: [FeedMediaItem]
    ) {
        self.postId = postId
        self.familyId = familyId
        self.ownerUserId = ownerUserId
        self.babyIds = babyIds
        self.caption = caption
        self.visibility = visibility
        self.status = status
        self.createdAt = createdAt
        self.items = items
    }
}

public struct FamilyFeedListData: Decodable, Sendable, Equatable {
    public let items: [FeedPostItem]
    public let nextCursor: String?
    public let cacheTtlSeconds: Int

    public init(items: [FeedPostItem], nextCursor: String? = nil, cacheTtlSeconds: Int) {
        self.items = items
        self.nextCursor = nextCursor
        self.cacheTtlSeconds = cacheTtlSeconds
    }
}

// MARK: - Endpoint

enum FeedsEndpoint: Endpoint {
    case listFamily(familyId: String, cursor: String?, limit: Int)

    var path: String {
        switch self {
        case .listFamily:
            return "/v1/feeds/family"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listFamily:
            return .get
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case let .listFamily(familyId, cursor, limit):
            var items = [
                URLQueryItem(name: "familyId", value: familyId),
                URLQueryItem(name: "limit", value: String(limit)),
            ]
            if let cursor, !cursor.isEmpty {
                items.append(URLQueryItem(name: "cursor", value: cursor))
            }
            return items
        }
    }

    func encodeBody(with encoder: JSONEncoder) throws -> Data? {
        nil
    }
}

// MARK: - API

public struct FeedsAPI: Sendable {
    public static let defaultPageSize = 20

    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /v1/feeds/family
    public func listFamily(
        familyId: String,
        cursor: String? = nil,
        limit: Int = defaultPageSize
    ) async throws -> FamilyFeedListData {
        try await client.request(
            FeedsEndpoint.listFamily(familyId: familyId, cursor: cursor, limit: limit)
        )
    }
}
