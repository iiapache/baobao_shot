import Foundation

// MARK: - Models

public struct BabyData: Decodable, Sendable, Equatable {
    public let babyId: String
    public let familyId: String?
    public let name: String
    public let birthday: String
    public let gender: String
    public let fullName: String?
    public let birthTime: String?
    public let birthWeight: Double?
    public let birthLength: Double?
    public let birthPlace: String?
    public let timezone: String?
    public let avatarUrl: String?

    public init(
        babyId: String,
        familyId: String? = nil,
        name: String,
        birthday: String,
        gender: String,
        fullName: String? = nil,
        birthTime: String? = nil,
        birthWeight: Double? = nil,
        birthLength: Double? = nil,
        birthPlace: String? = nil,
        timezone: String? = nil,
        avatarUrl: String? = nil
    ) {
        self.babyId = babyId
        self.familyId = familyId
        self.name = name
        self.birthday = birthday
        self.gender = gender
        self.fullName = fullName
        self.birthTime = birthTime
        self.birthWeight = birthWeight
        self.birthLength = birthLength
        self.birthPlace = birthPlace
        self.timezone = timezone
        self.avatarUrl = avatarUrl
    }
}

public struct BabyListData: Decodable, Sendable, Equatable {
    public let items: [BabyData]

    public init(items: [BabyData]) {
        self.items = items
    }
}

public struct BabyDeleteData: Decodable, Sendable, Equatable {
    public let babyId: String

    public init(babyId: String) {
        self.babyId = babyId
    }
}

public struct BabyAvatarUploadData: Decodable, Sendable, Equatable {
    public let babyId: String
    public let avatarUrl: String?

    public init(babyId: String, avatarUrl: String?) {
        self.babyId = babyId
        self.avatarUrl = avatarUrl
    }
}

public struct CreateBabyRequest: Encodable, Sendable {
    public let name: String
    public let birthday: String
    public let gender: String
    public let birthTime: String?

    public init(name: String, birthday: String, gender: String, birthTime: String? = nil) {
        self.name = name
        self.birthday = birthday
        self.gender = gender
        self.birthTime = birthTime
    }
}

public struct UpdateBabyRequest: Encodable, Sendable {
    public let name: String?
    public let birthday: String?
    public let gender: String?
    public let birthTime: String?

    public init(
        name: String? = nil,
        birthday: String? = nil,
        gender: String? = nil,
        birthTime: String? = nil
    ) {
        self.name = name
        self.birthday = birthday
        self.gender = gender
        self.birthTime = birthTime
    }
}

// MARK: - Endpoints

enum BabyEndpoint: Endpoint {
    case create(familyId: String, body: CreateBabyRequest)
    case list(familyId: String)
    case get(babyId: String)
    case update(babyId: String, body: UpdateBabyRequest)
    case delete(babyId: String)
    case uploadAvatar(babyId: String, data: Data, contentType: String)

    var path: String {
        switch self {
        case let .create(familyId, _):
            return "/v1/families/\(familyId)/babies"
        case let .list(familyId):
            return "/v1/families/\(familyId)/babies"
        case let .get(babyId):
            return "/v1/babies/\(babyId)"
        case let .update(babyId, _):
            return "/v1/babies/\(babyId)"
        case let .delete(babyId):
            return "/v1/babies/\(babyId)"
        case let .uploadAvatar(babyId, _, _):
            return "/v1/babies/\(babyId)/avatar"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .create, .uploadAvatar:
            return .post
        case .list, .get:
            return .get
        case .update:
            return .patch
        case .delete:
            return .delete
        }
    }

    var headers: [String: String]? {
        switch self {
        case let .uploadAvatar(_, _, contentType):
            return ["Content-Type": contentType]
        case .create, .update:
            return ["Content-Type": "application/json; charset=utf-8"]
        case .list, .get, .delete:
            return nil
        }
    }

    func encodeBody(with encoder: JSONEncoder) throws -> Data? {
        switch self {
        case let .create(_, body):
            return try encoder.encode(body)
        case let .update(_, body):
            return try encoder.encode(body)
        case let .uploadAvatar(_, data, _):
            return data
        case .list, .get, .delete:
            return nil
        }
    }
}

// MARK: - BabyAPI

public struct BabyAPI: Sendable {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /v1/families/{familyId}/babies
    public func create(familyId: String, request: CreateBabyRequest) async throws -> BabyData {
        try await client.request(BabyEndpoint.create(familyId: familyId, body: request))
    }

    /// GET /v1/families/{familyId}/babies
    public func listByFamily(familyId: String) async throws -> BabyListData {
        try await client.request(BabyEndpoint.list(familyId: familyId))
    }

    /// GET /v1/babies/{babyId}
    public func get(babyId: String) async throws -> BabyData {
        try await client.request(BabyEndpoint.get(babyId: babyId))
    }

    /// PATCH /v1/babies/{babyId}
    public func update(babyId: String, request: UpdateBabyRequest) async throws -> BabyData {
        try await client.request(BabyEndpoint.update(babyId: babyId, body: request))
    }

    /// DELETE /v1/babies/{babyId}
    public func delete(babyId: String) async throws -> BabyDeleteData {
        try await client.request(BabyEndpoint.delete(babyId: babyId))
    }

    /// POST /v1/babies/{babyId}/avatar — raw image body
    public func uploadAvatar(
        babyId: String,
        imageData: Data,
        contentType: String = "image/jpeg"
    ) async throws -> BabyAvatarUploadData {
        try await client.request(
            BabyEndpoint.uploadAvatar(babyId: babyId, data: imageData, contentType: contentType)
        )
    }
}
