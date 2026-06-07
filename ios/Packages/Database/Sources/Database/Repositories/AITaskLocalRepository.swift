import Foundation
import GRDB

public struct AITaskLocalRecord: Sendable, Equatable {
    public var id: String
    public var state: String
    public var model: String?
    public var style: String?
    public var costCredits: Int
    public var sourceUrl: String
    public var resultUrl: String?
    public var createdAt: Int64

    public init(
        id: String,
        state: String,
        model: String? = nil,
        style: String? = nil,
        costCredits: Int = 0,
        sourceUrl: String,
        resultUrl: String? = nil,
        createdAt: Int64
    ) {
        self.id = id
        self.state = state
        self.model = model
        self.style = style
        self.costCredits = costCredits
        self.sourceUrl = sourceUrl
        self.resultUrl = resultUrl
        self.createdAt = createdAt
    }
}

/// Local mirror of in-flight / recent AI tasks (`ai_task_local` table).
public protocol AITaskLocalRepository: Sendable {
    func fetch(id: String) async throws -> AITaskLocalRecord?
    func fetchByState(_ state: String) async throws -> [AITaskLocalRecord]
    func save(_ task: AITaskLocalRecord) async throws
    func delete(id: String) async throws
}

extension AITaskLocalRecord: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "ai_task_local"

    enum Columns {
        static let id = Column("id")
        static let state = Column("state")
    }

    public init(row: Row) throws {
        id = row[Columns.id]
        state = row[Columns.state]
        model = row["model"]
        style = row["style"]
        costCredits = row["costCredits"]
        sourceUrl = row["sourceUrl"]
        resultUrl = row["resultUrl"]
        createdAt = row["createdAt"]
    }

    public func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.state] = state
        container["model"] = model
        container["style"] = style
        container["costCredits"] = costCredits
        container["sourceUrl"] = sourceUrl
        container["resultUrl"] = resultUrl
        container["createdAt"] = createdAt
    }
}

public struct GRDBAITaskLocalRepository: AITaskLocalRepository {
    private let dbWriter: any DatabaseWriter

    public init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    public func fetch(id: String) async throws -> AITaskLocalRecord? {
        try await dbWriter.read { db in
            try AITaskLocalRecord.fetchOne(db, key: id)
        }
    }

    public func fetchByState(_ state: String) async throws -> [AITaskLocalRecord] {
        try await dbWriter.read { db in
            try AITaskLocalRecord
                .filter(AITaskLocalRecord.Columns.state == state)
                .fetchAll(db)
        }
    }

    public func save(_ task: AITaskLocalRecord) async throws {
        try await dbWriter.write { db in
            try task.save(db)
        }
    }

    public func delete(id: String) async throws {
        _ = try await dbWriter.write { db in
            try AITaskLocalRecord.deleteOne(db, key: id)
        }
    }
}
