import DesignSystem
import XCTest
@testable import BabyCameraSettings

final class TimelineHTMLGeneratorTests: XCTestCase {
    func testGenerateContainsTimelineSectionsAndPhotoReferences() {
        let manifest = DataExportManifest(
            exportedAt: "2026-06-06T10:00:00Z",
            appVersion: "1.0.0",
            familyId: "fam_1",
            babies: [
                DataExportBaby(id: "baby_1", name: "小宝", birthDate: "2024-01-01"),
            ],
            milestones: [],
            photos: [
                DataExportPhoto(
                    id: "photo_1",
                    babyIds: ["baby_1"],
                    userId: "user_1",
                    takenAt: 1_700_000_000,
                    sha256: "abc",
                    archivePath: "photo_1.heic",
                    localOnly: false
                ),
            ]
        )

        let html = TimelineHTMLGenerator().generate(manifest: manifest, photosDirectoryName: "photos")

        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains(L10n.string("settings.export.html.heading")))
        XCTAssertTrue(html.contains("photos/photo_1.heic"))
        XCTAssertTrue(html.contains("小宝"))
    }
}
