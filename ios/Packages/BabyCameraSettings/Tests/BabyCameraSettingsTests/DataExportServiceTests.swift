import Database
import XCTest
@testable import BabyCameraSettings

final class DataExportServiceTests: XCTestCase {
    private var tempDirectory: URL!
    private var appDatabase: AppDatabase!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("data-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        appDatabase = try AppDatabase.makeInMemory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testExportCreatesZipWithMetadataTimelineAndPhotos() async throws {
        let photoURL = tempDirectory.appendingPathComponent("photo_1.heic")
        try Data("image-bytes".utf8).write(to: photoURL)

        try await seedSinglePhoto(filePath: photoURL.path)

        let service = makeService(pageSize: 1)
        var progressSnapshots: [DataExportProgress] = []

        let archiveURL = try await service.export(familyId: "fam_1") { progress in
            progressSnapshots.append(progress)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path))
        XCTAssertEqual(progressSnapshots.last?.phase, .completed)
        XCTAssertEqual(progressSnapshots.last?.completedItems, 1)

        let archiveData = try Data(contentsOf: archiveURL)
        let archiveText = String(data: archiveData, encoding: .isoLatin1) ?? ""
        XCTAssertTrue(archiveText.contains("metadata.json"))
        XCTAssertTrue(archiveText.contains("timeline.html"))
        XCTAssertTrue(archiveText.contains("photos/photo_1.heic"))
    }

    func testExportFailsWhenFamilyMissing() async throws {
        let service = makeService()
        do {
            _ = try await service.export(familyId: "fam_missing") { _ in }
            XCTFail("Expected familyNotFound")
        } catch let error as DataExportError {
            XCTAssertEqual(error, .familyNotFound)
        }
    }

    func testExportFailsWhenNoPhotos() async throws {
        try await appDatabase.makeBabyRepository().save(
            BabyRecord(
                id: "baby_1",
                familyId: "fam_1",
                name: "小宝",
                birthDate: "2024-01-01"
            )
        )

        let service = makeService()
        do {
            _ = try await service.export(familyId: "fam_1") { _ in }
            XCTFail("Expected noPhotosToExport")
        } catch let error as DataExportError {
            XCTAssertEqual(error, .noPhotosToExport)
        }
    }

    func testExportPaginatesLargePhotoSetWithoutLoadingAllAtOnce() async throws {
        try await appDatabase.makeBabyRepository().save(
            BabyRecord(
                id: "baby_1",
                familyId: "fam_1",
                name: "小宝",
                birthDate: "2024-01-01"
            )
        )

        let totalPhotos = 250
        for index in 0..<totalPhotos {
            let photoURL = tempDirectory.appendingPathComponent("photo_\(index).heic")
            try Data("image-\(index)".utf8).write(to: photoURL)
            try await appDatabase.makePhotoRepository().save(
                PhotoRecord(
                    id: "photo_\(index)",
                    babyIds: ["baby_1"],
                    userId: "user_1",
                    takenAt: Int64(1_700_000_000 + index),
                    sha256: "hash_\(index)",
                    filePath: photoURL.path
                )
            )
        }

        let service = makeService(pageSize: 50)
        let archiveURL = try await service.export(familyId: "fam_1") { _ in }

        let archiveData = try Data(contentsOf: archiveURL)
        let archiveText = String(data: archiveData, encoding: .isoLatin1) ?? ""
        XCTAssertTrue(archiveText.contains("metadata.json"))
        XCTAssertTrue(archiveText.contains("photo_0.heic"))
        XCTAssertTrue(archiveText.contains("photo_249.heic"))
    }

    func testExportReportsProgressWhileCopyingPhotos() async throws {
        try await seedSinglePhoto(
            filePath: tempDirectory.appendingPathComponent("photo_1.heic").path,
            writeFile: true
        )

        let service = makeService()
        var sawCopying = false
        _ = try await service.export(familyId: "fam_1") { progress in
            if progress.phase == .copyingPhotos {
                sawCopying = true
            }
        }
        XCTAssertTrue(sawCopying)
    }

    private func makeService(pageSize: Int = 200) -> DataExportService {
        DataExportService(
            babyRepository: appDatabase.makeBabyRepository(),
            photoRepository: appDatabase.makePhotoRepository(),
            milestoneRepository: appDatabase.makeMilestoneRepository(),
            metadataBuilder: DataExportMetadataBuilder(appVersion: "1.0.0"),
            configuration: DataExportConfiguration(pageSize: pageSize),
            exportsDirectory: tempDirectory.appendingPathComponent("exports", isDirectory: true)
        )
    }

    private func seedSinglePhoto(filePath: String, writeFile: Bool = true) async throws {
        if writeFile {
            try Data("image-bytes".utf8).write(to: URL(fileURLWithPath: filePath))
        }

        try await appDatabase.makeBabyRepository().save(
            BabyRecord(
                id: "baby_1",
                familyId: "fam_1",
                name: "小宝",
                birthDate: "2024-01-01"
            )
        )
        try await appDatabase.makePhotoRepository().save(
            PhotoRecord(
                id: "photo_1",
                babyIds: ["baby_1"],
                userId: "user_1",
                takenAt: 1_700_000_000,
                sha256: "abc",
                filePath: filePath
            )
        )
    }
}
