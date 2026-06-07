import BabyCameraImageKit
import XCTest
@testable import BabyCameraCamera

final class CameraWatermarkHookTests: XCTestCase {
    private var tempDirectory: URL!
    private var mockOutput: MockPhotoOutput!
    private var pipeline: PhotoCapturePipeline!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        mockOutput = MockPhotoOutput()
        mockOutput.imageDataProvider = { PhotoCapturePipelineTestsHelper.validJPEG() }
        pipeline = PhotoCapturePipeline(
            photoOutput: mockOutput,
            fileWriter: PhotoFileWriter(baseDirectory: tempDirectory)
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testCapturePhotoSkipsWatermarkHookWhenBurnInDisabled() async throws {
        var hookCalled = false
        let overlayInfo = CameraOverlayInfo(
            babyId: "bb_1",
            babyName: "豆豆",
            birthDate: "2024-01-15",
            displayAge: "出生第 6 天",
            ageDay: 6
        )

        let result = try await pipeline.capturePhoto(
            overlayInfo: overlayInfo,
            settings: .default,
            watermarkHook: { _ in
                hookCalled = true
                throw PhotoCaptureError.captureFailed
            }
        )

        XCTAssertFalse(hookCalled)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
    }

    func testCapturePhotoInvokesWatermarkHookWhenBurnInEnabled() async throws {
        let watermarkedURL = tempDirectory.appendingPathComponent("watermarked.heic")
        let overlayInfo = CameraOverlayInfo(
            babyId: "bb_1",
            babyName: "豆豆",
            birthDate: "2024-01-15",
            displayAge: "出生第 6 天",
            ageDay: 6
        )
        var receivedRequest: CameraWatermarkRequest?

        let result = try await pipeline.capturePhoto(
            overlayInfo: overlayInfo,
            settings: CameraSettings(burnInWatermark: true),
            watermarkHook: { request in
                receivedRequest = request
                try Data().write(to: watermarkedURL)
                return watermarkedURL
            }
        )

        XCTAssertEqual(receivedRequest?.overlayInfo, overlayInfo)
        XCTAssertEqual(result.fileURL, watermarkedURL)
    }

    func testNoOpWatermarkHookReturnsSourceURL() async throws {
        let overlayInfo = CameraOverlayInfo(
            babyId: "bb_1",
            babyName: "豆豆",
            birthDate: "2024-01-15",
            displayAge: "出生第 6 天",
            ageDay: 6
        )

        let result = try await pipeline.capturePhoto(
            overlayInfo: overlayInfo,
            settings: CameraSettings(burnInWatermark: true),
            watermarkHook: CameraWatermarkHooks.noOp
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
    }
}
