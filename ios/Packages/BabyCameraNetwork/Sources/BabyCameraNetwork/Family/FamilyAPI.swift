import Foundation

// MARK: - Models

public struct FamilySummaryData: Decodable, Sendable, Equatable {
    public let familyId: String
    public let name: String
    public let role: String

    public init(familyId: String, name: String, role: String) {
        self.familyId = familyId
        self.name = name
        self.role = role
    }
}

public struct FamilyListData: Decodable, Sendable, Equatable {
    public let items: [FamilySummaryData]

    public init(items: [FamilySummaryData]) {
        self.items = items
    }
}

public struct FamilyMemberData: Decodable, Sendable, Equatable {
    public let userId: String
    public let role: String
    public let nickname: String?
    public let joinedAt: String

    public init(userId: String, role: String, nickname: String?, joinedAt: String) {
        self.userId = userId
        self.role = role
        self.nickname = nickname
        self.joinedAt = joinedAt
    }
}

public struct FamilyDetailData: Decodable, Sendable, Equatable {
    public let familyId: String
    public let name: String
    public let role: String
    public let members: [FamilyMemberData]
    public let babies: [FamilyBabyStub]?

    public init(
        familyId: String,
        name: String,
        role: String,
        members: [FamilyMemberData],
        babies: [FamilyBabyStub]? = nil
    ) {
        self.familyId = familyId
        self.name = name
        self.role = role
        self.members = members
        self.babies = babies
    }
}

/// 宝宝占位 — 详情接口内嵌，完整模型见 Baby 模块
public struct FamilyBabyStub: Decodable, Sendable, Equatable {
    public let babyId: String?
    public let name: String?

    public init(babyId: String? = nil, name: String? = nil) {
        self.babyId = babyId
        self.name = name
    }

    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           single.decodeNil() {
            babyId = nil
            name = nil
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        babyId = try container.decodeIfPresent(String.self, forKey: .babyId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
    }

    private enum CodingKeys: String, CodingKey {
        case babyId, name
    }
}

public struct InviteQRPayloadData: Codable, Sendable, Equatable {
    public let scheme: String
    public let code: String
    public let sig: String

    public init(scheme: String, code: String, sig: String) {
        self.scheme = scheme
        self.code = code
        self.sig = sig
    }
}

public struct InvitationData: Decodable, Sendable, Equatable {
    public let code: String
    public let expireAt: String
    public let maxUses: Int
    public let usedCount: Int
    public let qrPayload: InviteQRPayloadData

    public init(
        code: String,
        expireAt: String,
        maxUses: Int,
        usedCount: Int,
        qrPayload: InviteQRPayloadData
    ) {
        self.code = code
        self.expireAt = expireAt
        self.maxUses = maxUses
        self.usedCount = usedCount
        self.qrPayload = qrPayload
    }
}

public struct JoinFamilyData: Decodable, Sendable, Equatable {
    public let familyId: String
    public let role: String
    public let joinedAt: String

    public init(familyId: String, role: String, joinedAt: String) {
        self.familyId = familyId
        self.role = role
        self.joinedAt = joinedAt
    }
}

public struct RevokeInvitationData: Decodable, Sendable, Equatable {
    public let code: String

    public init(code: String) {
        self.code = code
    }
}

public struct FamilyIdData: Decodable, Sendable, Equatable {
    public let familyId: String

    public init(familyId: String) {
        self.familyId = familyId
    }
}

public struct RemoveMemberData: Decodable, Sendable, Equatable {
    public let userId: String?

    public init(userId: String? = nil) {
        self.userId = userId
    }
}

public struct FamilyMemberListData: Decodable, Sendable, Equatable {
    public let items: [FamilyMemberData]

    public init(items: [FamilyMemberData]) {
        self.items = items
    }
}

public struct UpdateMemberData: Decodable, Sendable, Equatable {
    public let userId: String
    public let role: String?
    public let nickname: String?

    public init(userId: String, role: String?, nickname: String?) {
        self.userId = userId
        self.role = role
        self.nickname = nickname
    }
}

public struct TransferAdminData: Decodable, Sendable, Equatable {
    public let familyId: String
    public let previousAdminUserId: String
    public let newAdminUserId: String
    public let transferredAt: String

    public init(
        familyId: String,
        previousAdminUserId: String,
        newAdminUserId: String,
        transferredAt: String
    ) {
        self.familyId = familyId
        self.previousAdminUserId = previousAdminUserId
        self.newAdminUserId = newAdminUserId
        self.transferredAt = transferredAt
    }
}

public struct TakeoverVoteData: Decodable, Sendable, Equatable {
    public let voteId: String
    public let status: String
    public let initiatorUserId: String
    public let eligibleVoters: Int
    public let approveCount: Int
    public let rejectCount: Int
    public let requiredApprovals: Int
    public let objectionEndsAt: String?

    public init(
        voteId: String,
        status: String,
        initiatorUserId: String,
        eligibleVoters: Int,
        approveCount: Int,
        rejectCount: Int,
        requiredApprovals: Int,
        objectionEndsAt: String? = nil
    ) {
        self.voteId = voteId
        self.status = status
        self.initiatorUserId = initiatorUserId
        self.eligibleVoters = eligibleVoters
        self.approveCount = approveCount
        self.rejectCount = rejectCount
        self.requiredApprovals = requiredApprovals
        self.objectionEndsAt = objectionEndsAt
    }
}

// MARK: - Request bodies

struct CreateFamilyRequest: Encodable, Sendable {
    let name: String
}

struct UpdateFamilyRequest: Encodable, Sendable {
    let name: String
}

struct JoinFamilyRequest: Encodable, Sendable {
    let relation: String
    let nickname: String?
}

struct UpdateMemberRequest: Encodable, Sendable {
    let role: String?
    let nickname: String?
}

struct TransferAdminRequest: Encodable, Sendable {
    let targetUserId: String
}

struct TakeoverRequest: Encodable, Sendable {
    let choice: String?
}

// MARK: - Endpoints

enum FamilyEndpoint: Endpoint {
    case createFamily(CreateFamilyRequest)
    case listFamilies
    case getFamily(String)
    case updateFamily(String, UpdateFamilyRequest)
    case deleteFamily(String)
    case createInvitation(String)
    case revokeInvitation(String, String)
    case joinInvitation(String, JoinFamilyRequest)
    case listMembers(String)
    case updateMember(String, String, UpdateMemberRequest)
    case removeMember(String, String)
    case transferAdmin(String, TransferAdminRequest)
    case takeover(String, TakeoverRequest?)

    var path: String {
        switch self {
        case .createFamily, .listFamilies:
            return "/v1/families"
        case let .getFamily(familyId), let .updateFamily(familyId, _), let .deleteFamily(familyId):
            return "/v1/families/\(familyId)"
        case let .createInvitation(familyId):
            return "/v1/families/\(familyId)/invitations"
        case let .revokeInvitation(familyId, code):
            return "/v1/families/\(familyId)/invitations/\(code)"
        case let .joinInvitation(code, _):
            return "/v1/invitations/\(code)/join"
        case let .listMembers(familyId):
            return "/v1/families/\(familyId)/members"
        case let .updateMember(familyId, userId, _):
            return "/v1/families/\(familyId)/members/\(userId)"
        case let .removeMember(familyId, userId):
            return "/v1/families/\(familyId)/members/\(userId)"
        case let .transferAdmin(familyId, _):
            return "/v1/families/\(familyId)/transfer"
        case let .takeover(familyId, _):
            return "/v1/families/\(familyId)/takeover"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .createFamily, .createInvitation, .joinInvitation, .transferAdmin, .takeover:
            return .post
        case .listFamilies, .getFamily, .listMembers:
            return .get
        case .updateFamily, .updateMember:
            return .patch
        case .deleteFamily, .revokeInvitation, .removeMember:
            return .delete
        }
    }

    func encodeBody(with encoder: JSONEncoder) throws -> Data? {
        switch self {
        case let .createFamily(body):
            return try encoder.encode(body)
        case let .updateFamily(_, body):
            return try encoder.encode(body)
        case let .joinInvitation(_, body):
            return try encoder.encode(body)
        case let .updateMember(_, _, body):
            return try encoder.encode(body)
        case let .transferAdmin(_, body):
            return try encoder.encode(body)
        case let .takeover(_, body):
            guard let body else { return nil }
            return try encoder.encode(body)
        default:
            return nil
        }
    }
}

// MARK: - FamilyAPI

public struct FamilyAPI: Sendable {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /v1/families
    public func createFamily(name: String) async throws -> FamilySummaryData {
        try await client.request(FamilyEndpoint.createFamily(CreateFamilyRequest(name: name)))
    }

    /// GET /v1/families
    public func listFamilies() async throws -> FamilyListData {
        try await client.request(FamilyEndpoint.listFamilies)
    }

    /// GET /v1/families/{familyId}
    public func getFamily(familyId: String) async throws -> FamilyDetailData {
        try await client.request(FamilyEndpoint.getFamily(familyId))
    }

    /// PATCH /v1/families/{familyId}
    public func updateFamily(familyId: String, name: String) async throws -> FamilySummaryData {
        try await client.request(
            FamilyEndpoint.updateFamily(familyId, UpdateFamilyRequest(name: name))
        )
    }

    /// DELETE /v1/families/{familyId}
    public func deleteFamily(familyId: String) async throws -> FamilyIdData {
        try await client.request(FamilyEndpoint.deleteFamily(familyId))
    }

    /// POST /v1/families/{familyId}/invitations
    public func createInvitation(familyId: String) async throws -> InvitationData {
        try await client.request(FamilyEndpoint.createInvitation(familyId))
    }

    /// DELETE /v1/families/{familyId}/invitations/{code}
    public func revokeInvitation(familyId: String, code: String) async throws -> RevokeInvitationData {
        try await client.request(FamilyEndpoint.revokeInvitation(familyId, code))
    }

    /// POST /v1/invitations/{code}/join
    public func joinFamily(code: String, relation: String, nickname: String?) async throws -> JoinFamilyData {
        try await client.request(
            FamilyEndpoint.joinInvitation(code, JoinFamilyRequest(relation: relation, nickname: nickname))
        )
    }

    /// GET /v1/families/{familyId}/members
    public func listMembers(familyId: String) async throws -> FamilyMemberListData {
        try await client.request(FamilyEndpoint.listMembers(familyId))
    }

    /// PATCH /v1/families/{familyId}/members/{userId}
    public func updateMember(
        familyId: String,
        userId: String,
        role: String? = nil,
        nickname: String? = nil
    ) async throws -> UpdateMemberData {
        try await client.request(
            FamilyEndpoint.updateMember(
                familyId,
                userId,
                UpdateMemberRequest(role: role, nickname: nickname)
            )
        )
    }

    /// DELETE /v1/families/{familyId}/members/{userId}
    public func removeMember(familyId: String, userId: String) async throws -> RemoveMemberData {
        try await client.request(FamilyEndpoint.removeMember(familyId, userId))
    }

    /// POST /v1/families/{familyId}/transfer
    public func transferAdmin(familyId: String, targetUserId: String) async throws -> TransferAdminData {
        try await client.request(
            FamilyEndpoint.transferAdmin(familyId, TransferAdminRequest(targetUserId: targetUserId))
        )
    }

    /// POST /v1/families/{familyId}/takeover
    public func takeover(familyId: String, choice: String? = nil) async throws -> TakeoverVoteData {
        let body = choice.map { TakeoverRequest(choice: $0) }
        return try await client.request(FamilyEndpoint.takeover(familyId, body))
    }
}
