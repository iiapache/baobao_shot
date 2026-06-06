import Foundation
import GRDB

/// Application SQLite database factory backed by GRDB.
public struct AppDatabase: Sendable {
    public let dbWriter: any DatabaseWriter

    public init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    /// Opens an on-disk database at the given path and applies pending migrations.
    public static func make(at path: String) throws -> AppDatabase {
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        let dbPool = try DatabasePool(path: path, configuration: config)
        try AppDatabaseMigrator.makeMigrator().migrate(dbPool)
        return AppDatabase(dbWriter: dbPool)
    }

    /// Creates an in-memory database for tests and previews.
    public static func makeInMemory() throws -> AppDatabase {
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        let dbQueue = try DatabaseQueue(path: ":memory:", configuration: config)
        try AppDatabaseMigrator.makeMigrator().migrate(dbQueue)
        return AppDatabase(dbWriter: dbQueue)
    }

    /// Re-applies migrations (no-op when schema is up to date).
    public func migrate() throws {
        try AppDatabaseMigrator.makeMigrator().migrate(dbWriter)
    }
}
