import XCTest
@testable import BabyCameraVideoKit

final class VideoExporterTests: XCTestCase {
    private let exporter = VideoExporter()
    private let probe = VideoProbe()

    func testExportFull720pProducesPRDCompliantMP4() async throws {
        let sourceURL = try TestVideoFactory.makeH264MP4(
            width: 1920,
            height: 1080,
            duration: 1.0
        )
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-720p-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: destinationURL) }

        let outputURL = try await exporter.export(
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            configuration: .prdDefault
        )

        let result = try await probe.probe(url: outputURL)
        XCTAssertEqual(result.containerFormat, .mp4)
        XCTAssertEqual(result.videoCodec, .h264)
        XCTAssertTrue(result.isPRDCompliant)
        XCTAssertLessThanOrEqual(max(result.naturalSize.width, result.naturalSize.height), 1280, accuracy: 2)
    }

    func testExportFamilyPreviewProducesMP4() async throws {
        let sourceURL = try TestVideoFactory.makeH264MP4(
            width: 1280,
            height: 720,
            duration: 1.0
        )
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-preview-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: destinationURL) }

        let outputURL = try await exporter.export(
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            configuration: .familyPreview
        )

        let result = try await probe.probe(url: outputURL)
        XCTAssertEqual(result.containerFormat, .mp4)
        XCTAssertEqual(result.videoCodec, .h264)
        XCTAssertTrue(result.isPRDCompliant)
    }

    func testExportWithoutAudioProducesValidMP4() async throws {
        let sourceURL = try TestVideoFactory.makeH264MP4(
            width: 640,
            height: 480,
            duration: 1.0
        )
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-muted-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: destinationURL) }

        let config = VideoExportConfiguration(profile: .full720p, includeAudio: false)
        let outputURL = try await exporter.export(
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            configuration: config
        )

        let result = try await probe.probe(url: outputURL)
        XCTAssertFalse(result.hasAudioTrack)
        XCTAssertTrue(result.isPRDCompliant)
    }

    func testExportPassthroughPreservesSource() async throws {
        let sourceURL = try TestVideoFactory.makeH264MP4(
            width: 640,
            height: 480,
            duration: 0.5
        )
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-passthrough-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: destinationURL) }

        let config = VideoExportConfiguration(profile: .passthrough)
        let outputURL = try await exporter.export(
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            configuration: config
        )

        let sourceProbe = try await probe.probe(url: sourceURL)
        let outputProbe = try await probe.probe(url: outputURL)

        XCTAssertEqual(outputProbe.containerFormat, .mp4)
        XCTAssertEqual(outputProbe.videoCodec, .h264)
        XCTAssertEqual(outputProbe.naturalSize.width, sourceProbe.naturalSize.width, accuracy: 1)
        XCTAssertEqual(outputProbe.naturalSize.height, sourceProbe.naturalSize.height, accuracy: 1)
    }

    func testExportProfileTargetMaxEdge() {
        XCTAssertEqual(VideoExportProfile.full720p.targetMaxEdge, 720)
        XCTAssertEqual(VideoExportProfile.full1080p.targetMaxEdge, 1080)
        XCTAssertEqual(VideoExportProfile.familyPreview.targetMaxEdge, 720)
        XCTAssertEqual(VideoExportProfile.passthrough.targetMaxEdge, 0)
    }
}
