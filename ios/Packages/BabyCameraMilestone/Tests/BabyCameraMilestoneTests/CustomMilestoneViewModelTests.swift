import Database
import XCTest
@testable import BabyCameraMilestone

@MainActor
final class CustomMilestoneViewModelTests: XCTestCase {
    private var appDatabase: AppDatabase!
    private var repository: GRDBCustomMilestoneRepository!
    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUpWithError() throws {
        appDatabase = try AppDatabase.makeInMemory()
        repository = GRDBCustomMilestoneRepository(
            repository: appDatabase.makeMilestoneRepository(),
            idGenerator: { "ms_custom_vm_1" }
        )
        calendar = Calendar(identifier: .gregorian)
        referenceDate = date("2025-01-01")
    }

    func testReloadPopulatesEntriesAndCalendarMarkers() async {
        let viewModel = makeViewModel()
        _ = try? await repository.create(
            babyId: "baby-vm",
            name: "第一次笑",
            date: date("2025-02-10")
        )

        await viewModel.reload()

        XCTAssertFalse(viewModel.entries.isEmpty)
        XCTAssertTrue(viewModel.calendarMarkedDays.contains("2025-02-10"))
        XCTAssertTrue(viewModel.calendarMarkedDays.contains("2025-01-03"))
    }

    func testCreateUpdatesListAndCalendar() async {
        let viewModel = makeViewModel()
        await viewModel.reload()
        let initialCount = viewModel.entries.count

        let created = await viewModel.create(name: "第一次坐", date: date("2025-03-20"))
        XCTAssertNotNil(created)
        XCTAssertEqual(viewModel.entries.count, initialCount + 1)
        XCTAssertTrue(viewModel.calendarMarkedDays.contains("2025-03-20"))
    }

    func testDeleteRemovesCalendarMarkerWhenLastEntryOnDay() async {
        let viewModel = makeViewModel()
        _ = try? await repository.create(
            babyId: "baby-vm",
            name: "唯一标记",
            date: date("2025-08-08")
        )
        await viewModel.reload()
        XCTAssertTrue(viewModel.calendarMarkedDays.contains("2025-08-08"))

        _ = await viewModel.delete(id: "ms_custom_vm_1")
        XCTAssertFalse(viewModel.calendarMarkedDays.contains("2025-08-08"))
    }

    func testPinnedAIPlaysStubReturnsEmptyUntilP3() async {
        let viewModel = makeViewModel()
        await viewModel.reload()
        await viewModel.refreshPinnedAIPlays(for: date("2025-01-03"))
        XCTAssertEqual(viewModel.pinnedAIPlayIDs, [])
    }

    func testPinnedAIPlaysUsesRecommenderWhenMarkedDay() async {
        let recommender = MockMilestoneAIPlayRecommender(playIDs: ["play_growth_card"])
        let viewModel = makeViewModel(recommender: recommender)
        await viewModel.reload()
        await viewModel.refreshPinnedAIPlays(for: date("2025-01-03"))
        XCTAssertEqual(viewModel.pinnedAIPlayIDs, ["play_growth_card"])
    }

    private func makeViewModel(
        recommender: any MilestoneAIPlayRecommending = StubMilestoneAIPlayRecommender()
    ) -> CustomMilestoneViewModel {
        CustomMilestoneViewModel(
            babyId: "baby-vm",
            birthDate: "2025-01-01",
            repository: repository,
            aiPlayRecommender: recommender,
            calendar: calendar,
            referenceDate: referenceDate
        )
    }

    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)!
    }
}

private struct MockMilestoneAIPlayRecommender: MilestoneAIPlayRecommending {
    let playIDs: [String]

    func recommendedPlayIDs(babyId: String, milestoneDate: Date) async -> [String] {
        _ = babyId
        _ = milestoneDate
        return playIDs
    }
}
