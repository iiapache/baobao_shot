import GRDB

/// GRDB migration registry. Historical migrations must never be edited — add new versions instead.
public enum AppDatabaseMigrator {
    public static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        registerV1Initial(&migrator)
        registerV1_1FamilySync(&migrator)
        return migrator
    }

    /// T2.4 验收：仅回放 `v1_initial`，供单测校验 11 张核心表。
    static func makeV1InitialOnlyMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        registerV1Initial(&migrator)
        return migrator
    }

    private static func registerV1Initial(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "baby") { t in
                t.column("id", .text).primaryKey()
                t.column("familyId", .text).notNull().indexed()
                t.column("name", .text).notNull()
                t.column("gender", .text)
                t.column("birthDate", .text).notNull()
                t.column("birthTime", .text)
                t.column("avatarPath", .text)
                t.column("updatedAt", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "photo") { t in
                t.column("id", .text).primaryKey()
                t.column("babyIds", .text).notNull()
                t.column("userId", .text).notNull()
                t.column("takenAt", .integer).notNull().indexed()
                t.column("lat", .double)
                t.column("lng", .double)
                t.column("sha256", .text).notNull().indexed()
                t.column("exif", .text)
                t.column("filePath", .text).notNull()
                t.column("localOnly", .boolean).notNull().defaults(to: false)
                t.column("updatedAt", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "derived") { t in
                t.column("id", .text).primaryKey()
                t.column("sourcePhotoId", .text).notNull().indexed()
                t.column("type", .text).notNull()
                t.column("filePath", .text).notNull()
                t.column("spec", .text)
                t.column("createdAt", .integer).notNull()
                t.column("updatedAt", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "ai_task_local") { t in
                t.column("id", .text).primaryKey()
                t.column("state", .text).notNull().indexed()
                t.column("model", .text)
                t.column("style", .text)
                t.column("costCredits", .integer).notNull().defaults(to: 0)
                t.column("sourceUrl", .text).notNull()
                t.column("resultUrl", .text)
                t.column("createdAt", .integer).notNull()
            }

            try db.create(table: "post_cache") { t in
                t.column("id", .text).primaryKey()
                t.column("familyId", .text).notNull()
                t.column("ownerUserId", .text).notNull()
                t.column("items", .text).notNull()
                t.column("caption", .text)
                t.column("createdAt", .integer).notNull()
                t.column("syncedAt", .integer)
            }
            try db.create(index: "idx_post_cache_familyId_createdAt", on: "post_cache", columns: ["familyId", "createdAt"])

            try db.create(table: "comment_cache") { t in
                t.column("id", .text).primaryKey()
                t.column("postId", .text).notNull().indexed()
                t.column("userId", .text).notNull()
                t.column("text", .text).notNull()
                t.column("createdAt", .integer).notNull()
            }

            try db.create(table: "like_cache") { t in
                t.primaryKey(["postId", "userId"])
                t.column("postId", .text).notNull()
                t.column("userId", .text).notNull()
                t.column("likedAt", .integer).notNull()
            }

            try db.create(table: "membership") { t in
                t.primaryKey(["userId", "familyId"])
                t.column("userId", .text).notNull()
                t.column("familyId", .text).notNull()
                t.column("role", .text).notNull()
                t.column("nickname", .text)
                t.column("joinAt", .integer).notNull()
            }

            try db.create(table: "credit_txn_cache") { t in
                t.column("id", .text).primaryKey()
                t.column("type", .text).notNull()
                t.column("amount", .integer).notNull()
                t.column("ref", .text)
                t.column("createdAt", .integer).notNull().indexed()
            }

            try db.create(table: "milestone") { t in
                t.column("id", .text).primaryKey()
                t.column("babyId", .text).notNull()
                t.column("name", .text).notNull()
                t.column("date", .integer).notNull()
                t.column("kind", .text).notNull()
                t.column("reminded", .boolean).notNull().defaults(to: false)
            }
            try db.create(index: "idx_milestone_babyId_date", on: "milestone", columns: ["babyId", "date"])

            try db.create(table: "setting") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }
        }
    }

    private static func registerV1_1FamilySync(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_1_family_sync") { db in
            try db.create(table: "family") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("myRole", .text).notNull()
                t.column("updatedAt", .integer).notNull().defaults(to: 0)
            }

            try db.alter(table: "membership") { t in
                t.add(column: "updatedAt", .integer).notNull().defaults(to: 0)
            }
        }
    }
}
