import Foundation
import GRDB

public struct BabyRecord: Sendable, Equatable, Codable {
    public var id: String
    public var familyId: String
    public var name: String
    public var gender: String?
    public var birthDate: String
    public var birthTime: String?
    public var avatarPath: String?
    public var updatedAt: Int64

    public init(
        id: String,
        familyId: String,
        name: String,
        gender: String? = nil,
        birthDate: String,
        birthTime: String? = nil,
        avatarPath: String? = nil,
        updatedAt: Int64 = 0
    ) {
        self.id = id
        self.familyId = familyId
        self.name = name
        self.gender = gender
        self.birthDate = birthDate
        self.birthTime = birthTime
        self.avatarPath = avatarPath
        self.updatedAt = updatedAt
    }
}

/// Local cache for baby profiles with GRDB persistence and network sync (T1.19).
public protocol BabyRepository: Sendable {
    func fetchAll(familyId: String) async throws -> [BabyRecord]
    func fetch(id: String) async throws -> BabyRecord?
    func save(_ baby: BabyRecord) async throws
    func saveIfNewer(_ baby: BabyRecord) async throws -> Bool
    func delete(id: String) async throws
    func deleteByFamilyExcept(familyId: String, ids: Set<String>) async throws
}

extension BabyRecord: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "baby"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let familyId = Column(CodingKeys.familyId)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

/// GRDB-backed baby repository for local persistence.
public struct GRDBBabyRepository: BabyRepository {
    private let dbWriter: any DatabaseWriter

    public init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    public func fetchAll(familyId: String) async throws -> [BabyRecord] {
        try await dbWriter.read { db in
            try BabyRecord
                .filter(BabyRecord.Columns.familyId == familyId)
                .order(BabyRecord.Columns.updatedAt.desc)
                .fetchAll(db)
        }
    }

    public func fetch(id: String) async throws -> BabyRecord? {
        try await dbWriter.read { db in
            try BabyRecord.fetchOne(db, key: id)
        }
    }

    public func save(_ baby: BabyRecord) async throws {
        try await dbWriter.write { db in
            try baby.save(db)
        }
    }

    public func saveIfNewer(_ baby: BabyRecord) async throws -> Bool {
        try await dbWriter.write { db in
            let existing = try BabyRecord.fetchOne(db, key: baby.id)
            guard SyncMerge.shouldApplyRemote(localUpdatedAt: existing?.updatedAt, remoteUpdatedAt: baby.updatedAt) else {
                return false
            }
            try baby.save(db)
            return true
        }
    }

    public func delete(id: String) async throws {
        _ = try await dbWriter.write { db in
            try BabyRecord.deleteOne(db, key: id)
        }
    }

    public func deleteByFamilyExcept(familyId: String, ids: Set<String>) async throws {
        try await dbWriter.write { db in
            if ids.isEmpty {
                try BabyRecord
                    .filter(BabyRecord.Columns.familyId == familyId)
                    .deleteAll(db)
                return
            }
            try BabyRecord
                .filter(BabyRecord.Columns.familyId == familyId)
                .filter(!ids.contains(BabyRecord.Columns.id))
                .deleteAll(db)
        }
    }
}
