import DesignSystem
import XCTest
@testable import BabyCameraSettings

@MainActor
final class DataExportViewModelTests: XCTestCase {
    func testStartExportUpdatesProgressAndPresentsShareSheet() async {
        let scheduler = InMemoryDataExportBackgroundScheduler()
        let coordinator = DataExportBackgroundCoordinator(
            exportService: MockDataExportService(),
            scheduler: scheduler
        )
        let viewModel = DataExportViewModel(coordinator: coordinator, familyId: "fam_1")

        viewModel.startExport()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.state, .completed(URL(fileURLWithPath: "/tmp/export.zip")))
        XCTAssertTrue(viewModel.isShareSheetPresented)
        XCTAssertEqual(scheduler.lastSubmittedRequest?.identifier, DataExportConfiguration.backgroundTaskIdentifier)
    }

    func testStartExportHandlesFailure() async {
        let coordinator = DataExportBackgroundCoordinator(
            exportService: MockDataExportService(shouldFail: true),
            scheduler: InMemoryDataExportBackgroundScheduler()
        )
        let viewModel = DataExportViewModel(coordinator: coordinator, familyId: "fam_1")

        viewModel.startExport()
        try? await Task.sleep(nanoseconds: 200_000_000)

        if case .failed(let message) = viewModel.state {
            XCTAssertEqual(message, L10n.string("settings.export.error.no_photos"))
        } else {
            XCTFail("Expected failed state")
        }
    }

    func testCancelExportResetsState() async {
        let coordinator = DataExportBackgroundCoordinator(
            exportService: MockSlowDataExportService(),
            scheduler: InMemoryDataExportBackgroundScheduler()
        )
        let viewModel = DataExportViewModel(coordinator: coordinator, familyId: "fam_1")

        viewModel.startExport()
        try? await Task.sleep(nanoseconds: 50_000_000)
        viewModel.cancelExport()

        XCTAssertEqual(viewModel.state, .idle)
    }
}

private struct MockDataExportService: DataExportServing {
    let shouldFail: Bool

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func export(
        familyId: String,
        progressHandler: @escaping @Sendable (DataExportProgress) -> Void
    ) async throws -> URL {
        if shouldFail {
            throw DataExportError.noPhotosToExport
        }
        progressHandler(DataExportProgress(phase: .copyingPhotos, completedItems: 1, totalItems: 1))
        progressHandler(DataExportProgress(phase: .completed, completedItems: 1, totalItems: 1))
        return URL(fileURLWithPath: "/tmp/export.zip")
    }
}

private struct MockSlowDataExportService: DataExportServing {
    func export(
        familyId: String,
        progressHandler: @escaping @Sendable (DataExportProgress) -> Void
    ) async throws -> URL {
        progressHandler(DataExportProgress(phase: .preparing, completedItems: 0, totalItems: 10))
        try await Task.sleep(nanoseconds: 500_000_000)
        return URL(fileURLWithPath: "/tmp/export.zip")
    }
}
