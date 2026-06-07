import XCTest
@testable import Database

final class RepositoryTests: XCTestCase {
    func testFamilyRepositoryCRUD() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let repository = appDatabase.makeFamilyRepository()

        let family = FamilyRecord(id: "fam_1", name: "测试家庭", myRole: "admin", updatedAt: 100)
        try await repository.save(family)
        XCTAssertEqual(try await repository.fetch(id: "fam_1"), family)

        let newer = FamilyRecord(id: "fam_1", name: "新名字", myRole: "admin", updatedAt: 200)
        XCTAssertTrue(try await repository.saveIfNewer(newer))
        XCTAssertEqual(try await repository.fetch(id: "fam_1")?.name, "新名字")

        let older = FamilyRecord(id: "fam_1", name: "旧名字", myRole: "admin", updatedAt: 50)
        XCTAssertFalse(try await repository.saveIfNewer(older))
        XCTAssertEqual(try await repository.fetch(id: "fam_1")?.name, "新名字")
    }

    func testMembershipRepositoryCRUD() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let repository = appDatabase.makeMembershipRepository()

        let membership = MembershipRecord(
            userId: "user_1",
            familyId: "fam_1",
            role: "admin",
            nickname: "妈妈",
            joinAt: 100,
            updatedAt: 100
        )
        try await repository.save(membership)
        XCTAssertEqual(try await repository.fetch(userId: "user_1", familyId: "fam_1"), membership)

        let members = try await repository.fetchByFamily(familyId: "fam_1")
        XCTAssertEqual(members.count, 1)
    }

    func testBabyRepositoryCRUD() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let repository = appDatabase.makeBabyRepository()

        let baby = BabyRecord(
            id: "baby_1",
            familyId: "fam_1",
            name: "小宝",
            gender: "female",
            birthDate: "2024-01-15",
            updatedAt: 1_700_000_000
        )

        try await repository.save(baby)
        let fetched = try await repository.fetch(id: "baby_1")
        XCTAssertEqual(fetched, baby)

        let all = try await repository.fetchAll(familyId: "fam_1")
        XCTAssertEqual(all.count, 1)

        try await repository.delete(id: "baby_1")
        let deleted = try await repository.fetch(id: "baby_1")
        XCTAssertNil(deleted)
    }

    func testPhotoRepositoryCRUD() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let repository = appDatabase.makePhotoRepository()

        let photo = PhotoRecord(
            id: "photo_1",
            babyIds: ["baby_1", "baby_2"],
            userId: "user_1",
            takenAt: 1_700_000_000,
            sha256: "abc123",
            filePath: "/tmp/photo.heic"
        )

        try await repository.save(photo)
        let fetched = try await repository.fetch(id: "photo_1")
        XCTAssertEqual(fetched, photo)

        let byBaby = try await repository.fetchByBaby(babyId: "baby_1", limit: 10)
        XCTAssertEqual(byBaby.count, 1)
        XCTAssertEqual(try await repository.countByBaby(babyId: "baby_1"), 1)

        try await repository.delete(id: "photo_1")
        XCTAssertNil(try await repository.fetch(id: "photo_1"))
    }

    func testPhotoRepositoryPagination() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let repository = appDatabase.makePhotoRepository()

        for index in 0..<5 {
            try await repository.save(
                PhotoRecord(
                    id: "photo_\(index)",
                    babyIds: ["baby_1"],
                    userId: "user_1",
                    takenAt: Int64(1_700_000_000 + index),
                    sha256: "hash_\(index)",
                    filePath: "/tmp/photo_\(index).heic"
                )
            )
        }

        let firstPage = try await repository.fetchPageByBaby(babyId: "baby_1", before: nil, limit: 2)
        XCTAssertEqual(firstPage.map(\.id), ["photo_4", "photo_3"])

        let secondPage = try await repository.fetchPageByBaby(
            babyId: "baby_1",
            before: firstPage.last?.takenAt,
            limit: 2
        )
        XCTAssertEqual(secondPage.map(\.id), ["photo_2", "photo_1"])

        XCTAssertEqual(try await repository.countByBaby(babyId: "baby_1"), 5)
    }

    func testSettingRepositoryCRUD() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let repository = appDatabase.makeSettingRepository()

        let setting = SettingRecord(key: "currentBabyId", value: "baby_1")
        try await repository.save(setting)

        let fetched = try await repository.fetch(key: "currentBabyId")
        XCTAssertEqual(fetched, setting)

        try await repository.delete(key: "currentBabyId")
        XCTAssertNil(try await repository.fetch(key: "currentBabyId"))
    }

    func testMilestoneRepositoryCRUD() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let repository = appDatabase.makeMilestoneRepository()

        let milestone = MilestoneRecord(
            id: "ms_custom_1",
            babyId: "baby_1",
            name: "第一次游泳",
            date: 1_700_000_000,
            kind: MilestoneRecordKind.custom.rawValue
        )

        try await repository.save(milestone)
        XCTAssertEqual(try await repository.fetch(id: "ms_custom_1"), milestone)

        let byBaby = try await repository.fetchByBaby(babyId: "baby_1")
        XCTAssertEqual(byBaby.count, 1)
        XCTAssertEqual(byBaby.first?.recordKind, .custom)

        let updated = MilestoneRecord(
            id: "ms_custom_1",
            babyId: "baby_1",
            name: "第一次下水",
            date: 1_700_086_400,
            kind: MilestoneRecordKind.custom.rawValue,
            reminded: true
        )
        try await repository.save(updated)
        XCTAssertEqual(try await repository.fetch(id: "ms_custom_1")?.name, "第一次下水")
        XCTAssertEqual(try await repository.fetch(id: "ms_custom_1")?.reminded, true)

        try await repository.delete(id: "ms_custom_1")
        XCTAssertNil(try await repository.fetch(id: "ms_custom_1"))
    }

    func testAITaskLocalRepositoryCRUD() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let repository = appDatabase.makeAITaskLocalRepository()

        let task = AITaskLocalRecord(
            id: "tsk_001",
            state: "succeeded",
            model: "seedream",
            style: "cartoon",
            costCredits: 8,
            sourceUrl: "https://cdn.example/input.heic",
            resultUrl: "https://cdn.example/output.heic",
            createdAt: 1_700_000_000
        )

        try await repository.save(task)
        XCTAssertEqual(try await repository.fetch(id: "tsk_001"), task)

        let byState = try await repository.fetchByState("succeeded")
        XCTAssertEqual(byState.count, 1)

        let downloaded = AITaskLocalRecord(
            id: "tsk_001",
            state: "downloaded",
            model: "seedream",
            style: "cartoon",
            costCredits: 8,
            sourceUrl: "https://cdn.example/input.heic",
            resultUrl: "https://cdn.example/output.heic",
            createdAt: 1_700_000_000
        )
        try await repository.save(downloaded)
        XCTAssertEqual(try await repository.fetch(id: "tsk_001")?.state, "downloaded")

        try await repository.delete(id: "tsk_001")
        XCTAssertNil(try await repository.fetch(id: "tsk_001"))
    }

    func testDerivedRepositoryCRUD() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let repository = appDatabase.makeDerivedRepository()

        let derived = DerivedRecord(
            id: "drv_001",
            sourcePhotoId: "photo_001",
            type: DerivedAssetKind.aiImage.rawValue,
            filePath: "/tmp/derived.heic",
            specJSON: #"{"taskId":"tsk_001"}"#,
            createdAt: 1_700_000_000,
            updatedAt: 1_700_000_000
        )

        try await repository.save(derived)
        XCTAssertEqual(try await repository.fetch(id: "drv_001"), derived)

        let bySource = try await repository.fetchBySourcePhoto(sourcePhotoId: "photo_001")
        XCTAssertEqual(bySource.count, 1)
        XCTAssertEqual(bySource.first?.sourcePhotoId, "photo_001")

        try await repository.delete(id: "drv_001")
        XCTAssertNil(try await repository.fetch(id: "drv_001"))
    }

    func testFeedCacheRepositoryTrimsTo100() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let repository = appDatabase.makeFeedCacheRepository()

        let posts = (1 ... 105).map { index in
            PostCacheRecord(
                id: "pst_\(index)",
                familyId: "fam_001",
                ownerUserId: "usr_001",
                itemsJSON: #"{"babyIds":[],"visibility":"family","status":"published","media":[]}"#,
                caption: "动态 \(index)",
                createdAt: Int64(index),
                syncedAt: Int64(index)
            )
        }

        try await repository.upsertPosts(posts, familyId: "fam_001", keepingLatest: 100)

        let cached = try await repository.fetchPosts(familyId: "fam_001", limit: 200)
        XCTAssertEqual(cached.count, 100)
        XCTAssertEqual(cached.first?.id, "pst_105")
        XCTAssertEqual(cached.last?.id, "pst_6")
        XCTAssertFalse(cached.contains(where: { $0.id == "pst_5" }))
    }

    func testLocalStorePathsLayout() throws {
        let root = URL(fileURLWithPath: "/tmp/BabyCameraStore", isDirectory: true)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01 UTC

        let paths = LocalStorePaths(storeRoot: root, calendar: calendar)
        let imageURL = paths.derivedFileURL(
            babyId: "baby_1",
            derivedId: "drv_001",
            kind: .aiImage,
            date: date
        )
        XCTAssertEqual(
            imageURL.path,
            "/tmp/BabyCameraStore/derived/baby_1/2024/01/drv_001.heic"
        )

        let videoURL = paths.derivedFileURL(
            babyId: "baby_1",
            derivedId: "drv_002",
            kind: .aiVideo,
            date: date
        )
        XCTAssertEqual(
            videoURL.path,
            "/tmp/BabyCameraStore/videos/baby_1/2024/01/drv_002.mp4"
        )
    }
}
