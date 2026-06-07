import GRDB
import XCTest
@testable import Database

final class MigrationTests: XCTestCase {
    /// T2.4 `v1_initial` 规定的 11 张核心表（不含后续 `v1_1_family_sync` 的 `family`）。
    private let v1InitialTables = [
        "ai_task_local",
        "baby",
        "comment_cache",
        "credit_txn_cache",
        "derived",
        "like_cache",
        "membership",
        "milestone",
        "photo",
        "post_cache",
        "setting",
    ]

    private let expectedTables = [
        "ai_task_local",
        "baby",
        "comment_cache",
        "credit_txn_cache",
        "derived",
        "family",
        "like_cache",
        "membership",
        "milestone",
        "photo",
        "post_cache",
        "setting",
    ]

    private let tableColumns: [String: [String]] = [
        "baby": ["id", "familyId", "name", "gender", "birthDate", "birthTime", "avatarPath", "updatedAt"],
        "photo": ["id", "babyIds", "userId", "takenAt", "lat", "lng", "sha256", "exif", "filePath", "localOnly", "updatedAt"],
        "derived": ["id", "sourcePhotoId", "type", "filePath", "spec", "createdAt", "updatedAt"],
        "ai_task_local": ["id", "state", "model", "style", "costCredits", "sourceUrl", "resultUrl", "createdAt"],
        "post_cache": ["id", "familyId", "ownerUserId", "items", "caption", "createdAt", "syncedAt"],
        "comment_cache": ["id", "postId", "userId", "text", "createdAt"],
        "like_cache": ["postId", "userId", "likedAt"],
        "family": ["id", "name", "myRole", "updatedAt"],
        "membership": ["userId", "familyId", "role", "nickname", "joinAt", "updatedAt"],
        "credit_txn_cache": ["id", "type", "amount", "ref", "createdAt"],
        "milestone": ["id", "babyId", "name", "date", "kind", "reminded"],
        "setting": ["key", "value"],
    ]

    private let tableIndexes: [String: [String]] = [
        "baby": ["baby_familyId"],
        "photo": ["photo_takenAt", "photo_sha256"],
        "derived": ["derived_sourcePhotoId"],
        "ai_task_local": ["ai_task_local_state"],
        "post_cache": ["idx_post_cache_familyId_createdAt"],
        "comment_cache": ["comment_cache_postId"],
        "credit_txn_cache": ["credit_txn_cache_createdAt"],
        "milestone": ["idx_milestone_babyId_date"],
    ]

    // MARK: - Table inventory

    func testV1InitialOnlyMigrationCreatesElevenCoreTables() throws {
        let appDatabase = try makeDatabase(migrator: AppDatabaseMigrator.makeV1InitialOnlyMigrator())
        let tables = try fetchUserTables(from: appDatabase)
        XCTAssertEqual(tables, v1InitialTables)
    }

    func testV1InitialMigrationCreatesAllTables() throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let tables = try fetchUserTables(from: appDatabase)
        XCTAssertEqual(tables, expectedTables)
    }

    func testAllTablesHaveExpectedColumns() throws {
        let appDatabase = try AppDatabase.makeInMemory()

        for (table, expectedColumns) in tableColumns.sorted(by: { $0.key < $1.key }) {
            let columns = try fetchColumnNames(table: table, from: appDatabase)
            XCTAssertEqual(columns, expectedColumns, "Unexpected columns for \(table)")
        }
    }

    func testExpectedIndexesExist() throws {
        let appDatabase = try AppDatabase.makeInMemory()

        for (table, expectedIndexes) in tableIndexes.sorted(by: { $0.key < $1.key }) {
            let indexes = try fetchIndexNames(table: table, from: appDatabase)
            for index in expectedIndexes {
                XCTAssertTrue(indexes.contains(index), "Missing index \(index) on \(table)")
            }
        }
    }

    func testCompositePrimaryKeysExist() throws {
        let appDatabase = try AppDatabase.makeInMemory()

        let likePK = try fetchPrimaryKeyColumns(table: "like_cache", from: appDatabase)
        XCTAssertEqual(likePK, ["postId", "userId"])

        let membershipPK = try fetchPrimaryKeyColumns(table: "membership", from: appDatabase)
        XCTAssertEqual(membershipPK, ["userId", "familyId"])
    }

    // MARK: - Idempotency

    func testMigrationReplayIsIdempotent() throws {
        let appDatabase = try AppDatabase.makeInMemory()

        XCTAssertNoThrow(try appDatabase.migrate())
        XCTAssertNoThrow(try appDatabase.migrate())

        let migrationCount = try appDatabase.dbWriter.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM grdb_migrations") ?? 0
        }

        XCTAssertEqual(migrationCount, 2)
    }

    func testMigrationReplayOnDiskIsIdempotent() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("babycamera-migration-replay-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let first = try AppDatabase.make(at: tempURL.path)
        let tablesAfterFirst = try fetchUserTables(from: first)

        try first.migrate()
        try first.migrate()

        let migrationCount = try first.dbWriter.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM grdb_migrations") ?? 0
        }
        let tablesAfterReplay = try fetchUserTables(from: first)

        XCTAssertEqual(migrationCount, 2)
        XCTAssertEqual(tablesAfterReplay, tablesAfterFirst)
    }

    // MARK: - Cold-start performance (T2.4)

    func testColdStartMigrationCompletesWithinBudget() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("babycamera-migration-perf-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let start = CFAbsoluteTimeGetCurrent()
        _ = try AppDatabase.make(at: tempURL.path)
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1_000

        // T2.4 验收：冷启动迁移 ≤ 200ms（真机/模拟器基准；CI 防 gross regression）
        XCTAssertLessThan(
            elapsedMs,
            200,
            "cold-start migration took \(String(format: "%.1f", elapsedMs))ms (budget 200ms)"
        )
    }

    // MARK: - Helpers

    private func makeDatabase(migrator: DatabaseMigrator) throws -> AppDatabase {
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        let dbQueue = try DatabaseQueue(path: ":memory:", configuration: config)
        try migrator.migrate(dbQueue)
        return AppDatabase(dbWriter: dbQueue)
    }

    private func fetchUserTables(from appDatabase: AppDatabase) throws -> [String] {
        try appDatabase.dbWriter.read { db in
            try String.fetchAll(
                db,
                sql: """
                SELECT name FROM sqlite_master
                WHERE type = 'table'
                  AND name NOT LIKE 'sqlite_%'
                  AND name != 'grdb_migrations'
                ORDER BY name
                """
            )
        }
    }

    private func fetchColumnNames(table: String, from appDatabase: AppDatabase) throws -> [String] {
        try appDatabase.dbWriter.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(\(table))")
                .map { $0["name"] as String }
        }
    }

    private func fetchIndexNames(table: String, from appDatabase: AppDatabase) throws -> [String] {
        try appDatabase.dbWriter.read { db in
            try String.fetchAll(
                db,
                sql: """
                SELECT name FROM sqlite_master
                WHERE type = 'index' AND tbl_name = ?
                ORDER BY name
                """,
                arguments: [table]
            )
        }
    }

    private func fetchPrimaryKeyColumns(table: String, from appDatabase: AppDatabase) throws -> [String] {
        try appDatabase.dbWriter.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(\(table))")
                .filter { ($0["pk"] as Int64) > 0 }
                .sorted { ($0["pk"] as Int64) < ($1["pk"] as Int64) }
                .map { $0["name"] as String }
        }
    }
}
