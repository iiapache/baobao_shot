import Foundation
import GRDB

public struct DerivedRecord: Sendable, Equatable {
    public var id: String
    public var sourcePhotoId: String
    public var type: String
    public var filePath: String
    public var specJSON: String?
    public var createdAt: Int64
    public var updatedAt: Int64

    public init(
        id: String,
        sourcePhotoId: String,
        type: String,
        filePath: String,
        specJSON: String? = nil,
        createdAt: Int64,
        updatedAt: Int64 = 0
    ) {
        self.id = id
        self.sourcePhotoId = sourcePhotoId
        self.type = type
        self.filePath = filePath
        self.specJSON = specJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Local cache for edited / AI-derived assets.
public protocol DerivedRepository: Sendable {
    func fetch(id: String) async throws -> DerivedRecord?
    func fetchBySourcePhoto(sourcePhotoId: String) async throws -> [DerivedRecord]
    func save(_ derived: DerivedRecord) async throws
    func delete(id: String) async throws
}

extension DerivedRecord: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "derived"

    enum Columns {
        static let id = Column("id")
        static let sourcePhotoId = Column("sourcePhotoId")
    }

    public init(row: Row) throws {
        id = row[Columns.id]
        sourcePhotoId = row[Columns.sourcePhotoId]
        type = row["type"]
        filePath = row["filePath"]
        specJSON = row["spec"]
        createdAt = row["createdAt"]
        updatedAt = row["updatedAt"]
    }

    public func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.sourcePhotoId] = sourcePhotoId
        container["type"] = type
        container["filePath"] = filePath
        container["spec"] = specJSON
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
    }
}

public struct GRDBDerivedRepository: DerivedRepository {
    private let dbWriter: any DatabaseWriter

    public init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    public func fetch(id: String) async throws -> DerivedRecord? {
        try await dbWriter.read { db in
            try DerivedRecord.fetchOne(db, key: id)
        }
    }

    public func fetchBySourcePhoto(sourcePhotoId: String) async throws -> [DerivedRecord] {
        try await dbWriter.read { db in
            try DerivedRecord
                .filter(DerivedRecord.Columns.sourcePhotoId == sourcePhotoId)
                .fetchAll(db)
        }
    }

    public func save(_ derived: DerivedRecord) async throws {
        try await dbWriter.write { db in
            try derived.save(db)
        }
    }

    public func delete(id: String) async throws {
        _ = try await dbWriter.write { db in
            try DerivedRecord.deleteOne(db, key: id)
        }
    }
}
