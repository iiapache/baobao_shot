import Foundation
import GRDB

public struct SettingRecord: Sendable, Equatable, Codable {
    public var key: String
    public var value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// Key-value app settings (`setting` table).
public protocol SettingRepository: Sendable {
    func fetch(key: String) async throws -> SettingRecord?
    func save(_ setting: SettingRecord) async throws
    func delete(key: String) async throws
}

extension SettingRecord: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "setting"
}

/// GRDB-backed settings repository.
public struct GRDBSettingRepository: SettingRepository {
    private let dbWriter: any DatabaseWriter

    public init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    public func fetch(key: String) async throws -> SettingRecord? {
        try await dbWriter.read { db in
            try SettingRecord.fetchOne(db, key: key)
        }
    }

    public func save(_ setting: SettingRecord) async throws {
        try await dbWriter.write { db in
            try setting.save(db)
        }
    }

    public func delete(key: String) async throws {
        _ = try await dbWriter.write { db in
            try SettingRecord.deleteOne(db, key: key)
        }
    }
}
