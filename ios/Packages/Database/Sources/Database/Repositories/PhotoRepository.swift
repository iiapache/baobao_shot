import Foundation
import GRDB

public struct PhotoRecord: Sendable, Equatable {
    public var id: String
    public var babyIds: [String]
    public var userId: String
    public var takenAt: Int64
    public var lat: Double?
    public var lng: Double?
    public var sha256: String
    public var exifJSON: String?
    public var filePath: String
    public var localOnly: Bool
    public var updatedAt: Int64

    public init(
        id: String,
        babyIds: [String],
        userId: String,
        takenAt: Int64,
        lat: Double? = nil,
        lng: Double? = nil,
        sha256: String,
        exifJSON: String? = nil,
        filePath: String,
        localOnly: Bool = false,
        updatedAt: Int64 = 0
    ) {
        self.id = id
        self.babyIds = babyIds
        self.userId = userId
        self.takenAt = takenAt
        self.lat = lat
        self.lng = lng
        self.sha256 = sha256
        self.exifJSON = exifJSON
        self.filePath = filePath
        self.localOnly = localOnly
        self.updatedAt = updatedAt
    }
}

/// Local cache for original photos. Implementation will use GRDB + file system (T2.4+).
public protocol PhotoRepository: Sendable {
    func fetch(id: String) async throws -> PhotoRecord?
    func fetchByBaby(babyId: String, limit: Int) async throws -> [PhotoRecord]
    func fetchPageByBaby(babyId: String, before takenAt: Int64?, limit: Int) async throws -> [PhotoRecord]
    func countByBaby(babyId: String) async throws -> Int
    func save(_ photo: PhotoRecord) async throws
    func delete(id: String) async throws
}

extension PhotoRecord: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "photo"

    enum Columns {
        static let id = Column("id")
        static let babyIds = Column("babyIds")
        static let takenAt = Column("takenAt")
        static let sha256 = Column("sha256")
    }

    public init(row: Row) throws {
        id = row[Columns.id]
        babyIds = try JSONStringArray.decode(row[Columns.babyIds])
        userId = row["userId"]
        takenAt = row[Columns.takenAt]
        lat = row["lat"]
        lng = row["lng"]
        sha256 = row[Columns.sha256]
        exifJSON = row["exif"]
        filePath = row["filePath"]
        localOnly = row["localOnly"]
        updatedAt = row["updatedAt"]
    }

    public func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.babyIds] = try JSONStringArray.encode(babyIds)
        container["userId"] = userId
        container[Columns.takenAt] = takenAt
        container["lat"] = lat
        container["lng"] = lng
        container[Columns.sha256] = sha256
        container["exif"] = exifJSON
        container["filePath"] = filePath
        container["localOnly"] = localOnly
        container["updatedAt"] = updatedAt
    }
}

/// GRDB-backed photo repository for local persistence.
public struct GRDBPhotoRepository: PhotoRepository {
    private let dbWriter: any DatabaseWriter

    public init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    public func fetch(id: String) async throws -> PhotoRecord? {
        try await dbWriter.read { db in
            try PhotoRecord.fetchOne(db, key: id)
        }
    }

    public func fetchByBaby(babyId: String, limit: Int) async throws -> [PhotoRecord] {
        try await fetchPageByBaby(babyId: babyId, before: nil, limit: limit)
    }

    public func fetchPageByBaby(
        babyId: String,
        before takenAt: Int64?,
        limit: Int
    ) async throws -> [PhotoRecord] {
        try await dbWriter.read { db in
            var request = PhotoRecord
                .filter(sql: "babyIds LIKE ?", arguments: ["%\(babyId)%"])
                .order(PhotoRecord.Columns.takenAt.desc)
                .limit(limit)
            if let takenAt {
                request = request.filter(PhotoRecord.Columns.takenAt < takenAt)
            }
            return try request.fetchAll(db)
        }
    }

    public func countByBaby(babyId: String) async throws -> Int {
        try await dbWriter.read { db in
            try PhotoRecord
                .filter(sql: "babyIds LIKE ?", arguments: ["%\(babyId)%"])
                .fetchCount(db)
        }
    }

    public func save(_ photo: PhotoRecord) async throws {
        try await dbWriter.write { db in
            try photo.save(db)
        }
    }

    public func delete(id: String) async throws {
        _ = try await dbWriter.write { db in
            try PhotoRecord.deleteOne(db, key: id)
        }
    }
}
