import Foundation
import GRDB

public struct FamilyRecord: Sendable, Equatable, Codable {
    public var id: String
    public var name: String
    public var myRole: String
    public var updatedAt: Int64

    public init(id: String, name: String, myRole: String, updatedAt: Int64 = 0) {
        self.id = id
        self.name = name
        self.myRole = myRole
        self.updatedAt = updatedAt
    }
}

/// Local cache for families (`family` table).
public protocol FamilyRepository: Sendable {
    func fetchAll() async throws -> [FamilyRecord]
    func fetch(id: String) async throws -> FamilyRecord?
    func save(_ family: FamilyRecord) async throws
    func saveIfNewer(_ family: FamilyRecord) async throws -> Bool
    func delete(id: String) async throws
    func deleteAllExcept(ids: Set<String>) async throws
}

extension FamilyRecord: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "family"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

public struct GRDBFamilyRepository: FamilyRepository {
    private let dbWriter: any DatabaseWriter

    public init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    public func fetchAll() async throws -> [FamilyRecord] {
        try await dbWriter.read { db in
            try FamilyRecord
                .order(FamilyRecord.Columns.updatedAt.desc)
                .fetchAll(db)
        }
    }

    public func fetch(id: String) async throws -> FamilyRecord? {
        try await dbWriter.read { db in
            try FamilyRecord.fetchOne(db, key: id)
        }
    }

    public func save(_ family: FamilyRecord) async throws {
        try await dbWriter.write { db in
            try family.save(db)
        }
    }

    public func saveIfNewer(_ family: FamilyRecord) async throws -> Bool {
        try await dbWriter.write { db in
            let existing = try FamilyRecord.fetchOne(db, key: family.id)
            guard SyncMerge.shouldApplyRemote(localUpdatedAt: existing?.updatedAt, remoteUpdatedAt: family.updatedAt) else {
                return false
            }
            try family.save(db)
            return true
        }
    }

    public func delete(id: String) async throws {
        _ = try await dbWriter.write { db in
            try FamilyRecord.deleteOne(db, key: id)
        }
    }

    public func deleteAllExcept(ids: Set<String>) async throws {
        try await dbWriter.write { db in
            if ids.isEmpty {
                try FamilyRecord.deleteAll(db)
                return
            }
            try FamilyRecord
                .filter(!ids.contains(FamilyRecord.Columns.id))
                .deleteAll(db)
        }
    }
}
