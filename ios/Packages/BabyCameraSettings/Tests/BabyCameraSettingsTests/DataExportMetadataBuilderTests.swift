import Database
import XCTest
@testable import BabyCameraSettings

final class DataExportMetadataBuilderTests: XCTestCase {
    func testBuildManifestMapsDatabaseRecords() {
        let builder = DataExportMetadataBuilder(appVersion: "2.0.0")
        let manifest = builder.makeManifest(
            familyId: "fam_1",
            babies: [
                BabyRecord(
                    id: "baby_1",
                    familyId: "fam_1",
                    name: "小宝",
                    birthDate: "2024-01-01"
                ),
            ],
            milestones: [
                MilestoneRecord(
                    id: "ms_1",
                    babyId: "baby_1",
                    name: "第一次翻身",
                    date: 1_700_000_000,
                    kind: MilestoneRecordKind.custom.rawValue
                ),
            ],
            photos: [
                builder.makePhoto(
                    from: PhotoRecord(
                        id: "photo_1",
                        babyIds: ["baby_1"],
                        userId: "user_1",
                        takenAt: 1_700_000_000,
                        sha256: "abc",
                        filePath: "/tmp/photo_1.heic"
                    ),
                    archiveFileName: "photo_1.heic"
                ),
            ]
        )

        XCTAssertEqual(manifest.version, DataExportManifest.currentVersion)
        XCTAssertEqual(manifest.appVersion, "2.0.0")
        XCTAssertEqual(manifest.familyId, "fam_1")
        XCTAssertEqual(manifest.babies.count, 1)
        XCTAssertEqual(manifest.milestones.first?.name, "第一次翻身")
        XCTAssertEqual(manifest.photos.first?.archivePath, "photo_1.heic")
    }

    func testArchiveFileNamePreservesExtension() {
        let photo = PhotoRecord(
            id: "photo_1",
            babyIds: ["baby_1"],
            userId: "user_1",
            takenAt: 1,
            sha256: "abc",
            filePath: "/store/photo_1.JPG"
        )
        XCTAssertEqual(DataExportMetadataBuilder.archiveFileName(for: photo), "photo_1.jpg")
    }
}
