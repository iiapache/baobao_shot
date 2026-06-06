import XCTest
@testable import BabyCameraVideoKit

final class VideoProbeTests: XCTestCase {
    private let probe = VideoProbe()

    func testProbeDetectsH264MP4() async throws {
        let url = try TestVideoFactory.makeH264MP4(
            width: 1280,
            height: 720,
            duration: 2.0
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await probe.probe(url: url)

        XCTAssertEqual(result.containerFormat, .mp4)
        XCTAssertEqual(result.videoCodec, .h264)
        XCTAssertTrue(result.isPRDCompliant)
        XCTAssertFalse(result.hasAudioTrack)
        XCTAssertEqual(result.duration, 2.0, accuracy: 0.15)
        XCTAssertEqual(result.naturalSize.width, 1280, accuracy: 1)
        XCTAssertEqual(result.naturalSize.height, 720, accuracy: 1)
        XCTAssertGreaterThan(result.frameRate, 0)
    }

    func testProbeWithoutAudioTrack() async throws {
        let url = try TestVideoFactory.makeH264MP4()
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await probe.probe(url: url)

        XCTAssertFalse(result.hasAudioTrack)
        XCTAssertTrue(result.isPRDCompliant)
    }

    func testProbeInvalidURLThrows() async {
        let remoteURL = URL(string: "https://example.com/video.mp4")!

        do {
            _ = try await probe.probe(url: remoteURL)
            XCTFail("Expected invalidURL error")
        } catch let error as VideoKitError {
            XCTAssertEqual(error, .invalidURL)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProbeMissingFileThrows() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).mp4")

        do {
            _ = try await probe.probe(url: url)
            XCTFail("Expected assetNotPlayable error")
        } catch let error as VideoKitError {
            XCTAssertEqual(error, .assetNotPlayable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
