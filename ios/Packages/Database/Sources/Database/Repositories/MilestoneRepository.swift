import Foundation
import GRDB

public enum MilestoneRecordKind: String, Sendable, Codable {
    case builtin
    case custom
}

public struct MilestoneRecord: Sendable, Equatable, Codable {
    public var id: String
    public var babyId: String
    public var name: String
    public var date: Int64
    public var kind: String
    public var reminded: Bool

    public init(
        id: String,
        babyId: String,
        name: String,
        date: Int64,
        kind: String,
        reminded: Bool = false
    ) {
        self.id = id
        self.babyId = babyId
        self.name = name
        self.date = date
        self.kind = kind
        self.reminded = reminded
    }

    public var recordKind: MilestoneRecordKind {
        MilestoneRecordKind(rawValue: kind) ?? .custom
    }
}

extension MilestoneRecord: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "milestone"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let babyId = Column(CodingKeys.babyId)
        static let date = Column(CodingKeys.date)
        static let kind = Column(CodingKeys.kind)
    }
}

/// Custom + built-in milestone cache (`milestone` table).
public protocol MilestoneRepository: Sendable {
    func fetchByBaby(babyId: String) async throws -> [MilestoneRecord]
    func fetch(id: String) async throws -> MilestoneRecord?
    func save(_ milestone: MilestoneRecord) async throws
    func delete(id: String) async throws
}

/// GRDB-backed milestone repository for local persistence.
public struct GRDBMilestoneRepository: MilestoneRepository {
    private let dbWriter: any DatabaseWriter

    public init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    public func fetchByBaby(babyId: String) async throws -> [MilestoneRecord] {
        try await dbWriter.read { db in
            try MilestoneRecord
                .filter(MilestoneRecord.Columns.babyId == babyId)
                .order(MilestoneRecord.Columns.date.asc)
                .fetchAll(db)
        }
    }

    public func fetch(id: String) async throws -> MilestoneRecord? {
        try await dbWriter.read { db in
            try MilestoneRecord.fetchOne(db, key: id)
        }
    }

    public func save(_ milestone: MilestoneRecord) async throws {
        try await dbWriter.write { db in
            try milestone.save(db)
        }
    }

    public func delete(id: String) async throws {
        _ = try await dbWriter.write { db in
            try MilestoneRecord.deleteOne(db, key: id)
        }
    }
}
