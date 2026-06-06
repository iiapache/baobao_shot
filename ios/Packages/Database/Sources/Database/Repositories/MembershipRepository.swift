import Foundation

public struct MembershipRecord: Sendable, Equatable {
    public var userId: String
    public var familyId: String
    public var role: String
    public var nickname: String?
    public var joinAt: Int64

    public init(
        userId: String,
        familyId: String,
        role: String,
        nickname: String? = nil,
        joinAt: Int64
    ) {
        self.userId = userId
        self.familyId = familyId
        self.role = role
        self.nickname = nickname
        self.joinAt = joinAt
    }
}

/// Local cache for family memberships (`membership` table).
public protocol MembershipRepository: Sendable {
    func fetch(userId: String, familyId: String) async throws -> MembershipRecord?
    func fetchByFamily(familyId: String) async throws -> [MembershipRecord]
    func save(_ membership: MembershipRecord) async throws
    func delete(userId: String, familyId: String) async throws
}
