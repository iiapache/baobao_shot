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

/// Local cache for baby profiles. Implementation will use GRDB + network sync (T1.19+).
public protocol BabyRepository: Sendable {
    func fetchAll(familyId: String) async throws -> [BabyRecord]
    func fetch(id: String) async throws -> BabyRecord?
    func save(_ baby: BabyRecord) async throws
    func delete(id: String) async throws
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

    public func delete(id: String) async throws {
        _ = try await dbWriter.write { db in
            try BabyRecord.deleteOne(db, key: id)
        }
    }
}
