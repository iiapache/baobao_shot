import XCTest
@testable import Database

final class RepositoryTests: XCTestCase {
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

        try await repository.delete(id: "photo_1")
        XCTAssertNil(try await repository.fetch(id: "photo_1"))
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
}
