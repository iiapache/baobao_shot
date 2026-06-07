import XCTest
@testable import Widgets

final class BabyWidgetThumbnailResolverTests: XCTestCase {
    func testResolveURLReturnsFileWhenExists() throws {
        let container = try TempWidgetAppGroupContainer()
        let root = try container.containerURL()
        let relativePath = "thumbnails/photo_1_200.jpg"
        let fileURL = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([0x01, 0x02]).write(to: fileURL)

        let resolved = BabyWidgetThumbnailResolver.resolveURL(
            relativePath: relativePath,
            containerURL: root
        )

        XCTAssertEqual(resolved, fileURL)
    }

    func testResolveURLReturnsNilForMissingFile() throws {
        let container = try TempWidgetAppGroupContainer()
        let root = try container.containerURL()

        let resolved = BabyWidgetThumbnailResolver.resolveURL(
            relativePath: "thumbnails/missing_200.jpg",
            containerURL: root
        )

        XCTAssertNil(resolved)
    }

    func testResolveURLReturnsNilForEmptyPath() throws {
        let container = try TempWidgetAppGroupContainer()
        let root = try container.containerURL()

        XCTAssertNil(BabyWidgetThumbnailResolver.resolveURL(relativePath: nil, containerURL: root))
        XCTAssertNil(BabyWidgetThumbnailResolver.resolveURL(relativePath: "", containerURL: root))
    }
}
