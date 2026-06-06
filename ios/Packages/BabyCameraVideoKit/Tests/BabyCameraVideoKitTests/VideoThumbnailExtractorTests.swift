import XCTest
@testable import BabyCameraVideoKit

final class VideoThumbnailExtractorTests: XCTestCase {
    private let extractor = VideoThumbnailExtractor()

    func testExtractThumbnailAtZeroSeconds() async throws {
        let url = try TestVideoFactory.makeH264MP4(
            width: 640,
            height: 480,
            duration: 1.0,
            color: .red
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let thumbnail = try await extractor.extractThumbnail(
            from: url,
            at: 0,
            maxEdgeLength: 256
        )

        XCTAssertGreaterThan(thumbnail.width, 0)
        XCTAssertGreaterThan(thumbnail.height, 0)
        XCTAssertLessThanOrEqual(max(thumbnail.width, thumbnail.height), 256)
    }

    func testExtractThumbnailMidpoint() async throws {
        let url = try TestVideoFactory.makeH264MP4(
            width: 800,
            height: 600,
            duration: 2.0,
            color: .blue
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let thumbnail = try await extractor.extractThumbnail(
            from: url,
            at: 1.0,
            maxEdgeLength: 200
        )

        XCTAssertLessThanOrEqual(max(thumbnail.width, thumbnail.height), 200)
        let aspectRatio = Double(thumbnail.width) / Double(thumbnail.height)
        let expectedRatio = 800.0 / 600.0
        XCTAssertEqual(aspectRatio, expectedRatio, accuracy: 0.05)
    }

    func testExtractThumbnailPreservesAspectRatio() async throws {
        let url = try TestVideoFactory.makeH264MP4(
            width: 1920,
            height: 1080,
            duration: 1.0
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let thumbnail = try await extractor.extractThumbnail(
            from: url,
            at: 0,
            maxEdgeLength: 256
        )

        let sourceRatio = 1920.0 / 1080.0
        let thumbRatio = Double(thumbnail.width) / Double(thumbnail.height)
        XCTAssertEqual(sourceRatio, thumbRatio, accuracy: 0.05)
    }

    func testExtractThumbnailClampsTimeBeyondDuration() async throws {
        let url = try TestVideoFactory.makeH264MP4(duration: 1.0)
        defer { try? FileManager.default.removeItem(at: url) }

        let thumbnail = try await extractor.extractThumbnail(
            from: url,
            at: 999,
            maxEdgeLength: 128
        )

        XCTAssertGreaterThan(thumbnail.width, 0)
    }
}
