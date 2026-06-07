import XCTest
@testable import BabyCameraSettings

final class DataExportBackgroundCoordinatorTests: XCTestCase {
    func testStartExportPersistsAndClearsJob() async throws {
        let jobStore = InMemoryDataExportJobStore()
        let coordinator = DataExportBackgroundCoordinator(
            exportService: MockDataExportService(),
            scheduler: InMemoryDataExportBackgroundScheduler(),
            jobStore: jobStore
        )

        _ = try await coordinator.startExport(familyId: "fam_1") { _ in }
        XCTAssertNil(jobStore.load())
    }

    func testResumePendingExportCompletesStoredJob() async {
        let jobStore = InMemoryDataExportJobStore()
        jobStore.save(DataExportJob(familyId: "fam_1"))

        let coordinator = DataExportBackgroundCoordinator(
            exportService: MockDataExportService(),
            scheduler: InMemoryDataExportBackgroundScheduler(),
            jobStore: jobStore
        )

        let success = await coordinator.resumePendingExportIfNeeded()
        XCTAssertTrue(success)
        XCTAssertNil(jobStore.load())
    }
}

private struct InMemoryDataExportJobStore: DataExportJobPersisting {
    private var job: DataExportJob?

    func load() -> DataExportJob? { job }
    func save(_ job: DataExportJob) { self.job = job }
    func clear() { job = nil }
}
