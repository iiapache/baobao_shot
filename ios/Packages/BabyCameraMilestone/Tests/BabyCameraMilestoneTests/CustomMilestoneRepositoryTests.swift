import Database
import XCTest
@testable import BabyCameraMilestone

final class CustomMilestoneRepositoryTests: XCTestCase {
    private var appDatabase: AppDatabase!
    private var repository: GRDBCustomMilestoneRepository!

    override func setUpWithError() throws {
        appDatabase = try AppDatabase.makeInMemory()
        repository = GRDBCustomMilestoneRepository(
            repository: appDatabase.makeMilestoneRepository(),
            idGenerator: { "ms_custom_test_1" }
        )
    }

    func testCreateFetchUpdateDelete() async throws {
        let created = try await repository.create(
            babyId: "baby-1",
            name: "第一次翻身",
            date: date("2025-03-10")
        )
        XCTAssertEqual(created.id, "ms_custom_test_1")
        XCTAssertEqual(created.name, "第一次翻身")

        let fetched = try await repository.fetch(id: "ms_custom_test_1")
        XCTAssertEqual(fetched, created)

        let all = try await repository.fetchAll(babyId: "baby-1")
        XCTAssertEqual(all.count, 1)

        var updated = created
        updated.name = "第一次独立翻身"
        updated.reminded = true
        try await repository.update(updated)

        let afterUpdate = try await repository.fetch(id: "ms_custom_test_1")
        XCTAssertEqual(afterUpdate?.name, "第一次独立翻身")
        XCTAssertEqual(afterUpdate?.reminded, true)

        try await repository.delete(id: "ms_custom_test_1")
        XCTAssertNil(try await repository.fetch(id: "ms_custom_test_1"))
    }

    func testIgnoresBuiltinRecords() async throws {
        let milestoneRepository = appDatabase.makeMilestoneRepository()
        try await milestoneRepository.save(
            MilestoneRecord(
                id: "ms_hundred_days",
                babyId: "baby-1",
                name: "百天",
                date: MilestoneDateCodec.startOfDayTimestamp(for: date("2025-04-20")),
                kind: MilestoneRecordKind.builtin.rawValue
            )
        )
        try await _ = repository.create(
            babyId: "baby-1",
            name: "自定义",
            date: date("2025-05-01")
        )

        let customOnly = try await repository.fetchAll(babyId: "baby-1")
        XCTAssertEqual(customOnly.count, 1)
        XCTAssertEqual(customOnly.first?.name, "自定义")
    }

    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)!
    }
}
