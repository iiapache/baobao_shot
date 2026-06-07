import Foundation
import GRDB

public struct MembershipRecord: Sendable, Equatable, Codable {
    public var userId: String
    public var familyId: String
    public var role: String
    public var nickname: String?
    public var joinAt: Int64
    public var updatedAt: Int64

    public init(
        userId: String,
        familyId: String,
        role: String,
        nickname: String? = nil,
        joinAt: Int64,
        updatedAt: Int64 = 0
    ) {
        self.userId = userId
        self.familyId = familyId
        self.role = role
        self.nickname = nickname
        self.joinAt = joinAt
        self.updatedAt = updatedAt
    }
}

/// Local cache for family memberships (`membership` table).
public protocol MembershipRepository: Sendable {
    func fetch(userId: String, familyId: String) async throws -> MembershipRecord?
    func fetchByFamily(familyId: String) async throws -> [MembershipRecord]
    func save(_ membership: MembershipRecord) async throws
    func saveIfNewer(_ membership: MembershipRecord) async throws -> Bool
    func delete(userId: String, familyId: String) async throws
    func deleteByFamilyExcept(familyId: String, userIds: Set<String>) async throws
}

extension MembershipRecord: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "membership"

    enum Columns {
        static let userId = Column(CodingKeys.userId)
        static let familyId = Column(CodingKeys.familyId)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

public struct GRDBMembershipRepository: MembershipRepository {
    private let dbWriter: any DatabaseWriter

    public init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    public func fetch(userId: String, familyId: String) async throws -> MembershipRecord? {
        try await dbWriter.read { db in
            try MembershipRecord
                .filter(MembershipRecord.Columns.userId == userId && MembershipRecord.Columns.familyId == familyId)
                .fetchOne(db)
        }
    }

    public func fetchByFamily(familyId: String) async throws -> [MembershipRecord] {
        try await dbWriter.read { db in
            try MembershipRecord
                .filter(MembershipRecord.Columns.familyId == familyId)
                .order(MembershipRecord.Columns.updatedAt.desc)
                .fetchAll(db)
        }
    }

    public func save(_ membership: MembershipRecord) async throws {
        try await dbWriter.write { db in
            try membership.save(db)
        }
    }

    public func saveIfNewer(_ membership: MembershipRecord) async throws -> Bool {
        try await dbWriter.write { db in
            let existing = try MembershipRecord
                .filter(
                    MembershipRecord.Columns.userId == membership.userId
                        && MembershipRecord.Columns.familyId == membership.familyId
                )
                .fetchOne(db)
            guard SyncMerge.shouldApplyRemote(localUpdatedAt: existing?.updatedAt, remoteUpdatedAt: membership.updatedAt) else {
                return false
            }
            try membership.save(db)
            return true
        }
    }

    public func delete(userId: String, familyId: String) async throws {
        _ = try await dbWriter.write { db in
            try MembershipRecord
                .filter(MembershipRecord.Columns.userId == userId && MembershipRecord.Columns.familyId == familyId)
                .deleteAll(db)
        }
    }

    public func deleteByFamilyExcept(familyId: String, userIds: Set<String>) async throws {
        try await dbWriter.write { db in
            if userIds.isEmpty {
                try MembershipRecord
                    .filter(MembershipRecord.Columns.familyId == familyId)
                    .deleteAll(db)
                return
            }
            try MembershipRecord
                .filter(MembershipRecord.Columns.familyId == familyId)
                .filter(!userIds.contains(MembershipRecord.Columns.userId))
                .deleteAll(db)
        }
    }
}
