import Database
import XCTest
@testable import BabyCameraBaby

final class InMemoryBabyRepositoryTests: XCTestCase {
    func testSaveFetchAndDelete() async throws {
        let repository = InMemoryBabyRepository()
        let record = BabyRecord(
            id: "bb_1",
            familyId: "fam_1",
            name: "豆豆",
            gender: "male",
            birthDate: "2024-01-15",
            birthTime: "08:30",
            updatedAt: 1
        )

        try await repository.save(record)
        let fetched = try await repository.fetch(id: "bb_1")
        XCTAssertEqual(fetched, record)

        let all = try await repository.fetchAll(familyId: "fam_1")
        XCTAssertEqual(all.count, 1)

        try await repository.delete(id: "bb_1")
        let missing = try await repository.fetch(id: "bb_1")
        XCTAssertNil(missing)
    }

    func testFetchAllOrdersByUpdatedAtDesc() async throws {
        let repository = InMemoryBabyRepository()
        try await repository.save(
            BabyRecord(id: "bb_old", familyId: "fam_1", name: "旧", birthDate: "2024-01-01", updatedAt: 1)
        )
        try await repository.save(
            BabyRecord(id: "bb_new", familyId: "fam_1", name: "新", birthDate: "2024-02-01", updatedAt: 99)
        )

        let all = try await repository.fetchAll(familyId: "fam_1")
        XCTAssertEqual(all.map(\.id), ["bb_new", "bb_old"])
    }
}
