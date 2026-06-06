import GRDB
import XCTest
@testable import Database

final class MigrationTests: XCTestCase {
    private let expectedTables = [
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

    private let tableColumns: [String: [String]] = [
        "baby": ["id", "familyId", "name", "gender", "birthDate", "birthTime", "avatarPath", "updatedAt"],
        "photo": ["id", "babyIds", "userId", "takenAt", "lat", "lng", "sha256", "exif", "filePath", "localOnly", "updatedAt"],
        "derived": ["id", "sourcePhotoId", "type", "filePath", "spec", "createdAt", "updatedAt"],
        "ai_task_local": ["id", "state", "model", "style", "costCredits", "sourceUrl", "resultUrl", "createdAt"],
        "post_cache": ["id", "familyId", "ownerUserId", "items", "caption", "createdAt", "syncedAt"],
        "comment_cache": ["id", "postId", "userId", "text", "createdAt"],
        "like_cache": ["postId", "userId", "likedAt"],
        "membership": ["userId", "familyId", "role", "nickname", "joinAt"],
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

        XCTAssertEqual(migrationCount, 1)
    }

    // MARK: - Cold-start performance (T2.4 acceptance placeholder)

    func testColdStartMigrationCompletesWithinBudget() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("babycamera-migration-perf-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let start = CFAbsoluteTimeGetCurrent()
        _ = try AppDatabase.make(at: tempURL.path)
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1_000

        // Placeholder budget from T2.4: cold-start migration ≤ 200ms on device.
        // CI / simulator may vary; this guards gross regressions during development.
        XCTAssertLessThan(
            elapsedMs,
            200,
            "v1_initial migration took \(String(format: "%.1f", elapsedMs))ms (budget 200ms)"
        )
    }

    // MARK: - Helpers

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
