import BabyCameraImageKit
import XCTest
@testable import BabyCameraCamera

final class PhotoCapturePipelineTests: XCTestCase {
    private var tempDirectory: URL!
    private var mockOutput: MockPhotoOutput!
    private var codec: ImageCodec!
    private var pipeline: PhotoCapturePipeline!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        mockOutput = MockPhotoOutput()
        mockOutput.imageDataProvider = { TestImageFactory.jpegData() }
        codec = ImageCodec()
        pipeline = PhotoCapturePipeline(
            photoOutput: mockOutput,
            codec: codec,
            fileWriter: PhotoFileWriter(baseDirectory: tempDirectory)
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testCapturePhotoWritesHEICFile() async throws {
        let result = try await pipeline.capturePhoto(preferences: .default)

        XCTAssertEqual(mockOutput.captureCallCount, 1)
        XCTAssertEqual(result.format, codec.isHEICSupported() ? .heic : .jpeg)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
        XCTAssertNil(result.livePhotoMovieURL)
        XCTAssertLessThanOrEqual(
            PhotoCaptureBenchmark.measure(latencySeconds: result.captureLatency).latencyMilliseconds,
            PhotoCaptureBenchmark.captureLatencyBudgetMilliseconds + 500
        )
    }

    func testCapturePhotoWritesJPEGWhenPreferred() async throws {
        var prefs = PhotoCapturePreferences.default
        prefs.preferredFormat = .jpeg

        let result = try await pipeline.capturePhoto(preferences: prefs)

        XCTAssertEqual(result.format, .jpeg)
        XCTAssertTrue(result.fileURL.pathExtension.lowercased() == "jpg")
    }

    func testCapturePhotoRejectsConcurrentCapture() async throws {
        mockOutput.simulatedLatency = 0.2
        async let first = pipeline.capturePhoto()
        try await Task.sleep(nanoseconds: 10_000_000)

        do {
            _ = try await pipeline.capturePhoto()
            XCTFail("Expected captureInProgress")
        } catch {
            XCTAssertEqual(error as? PhotoCaptureError, .captureInProgress)
        }

        _ = try await first
    }

    func testCapturePhotoPropagatesOutputFailure() async {
        mockOutput.shouldFail = true

        do {
            _ = try await pipeline.capturePhoto()
            XCTFail("Expected captureFailed")
        } catch {
            XCTAssertEqual(error as? PhotoCaptureError, .captureFailed)
        }
    }

    func testFileWriterUsesYearMonthPath() throws {
        let writer = PhotoFileWriter(baseDirectory: tempDirectory)
        let id = UUID()
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 6))!
        let url = try writer.write(data: Data([0x01]), format: .jpeg, photoID: id, capturedAt: date)

        XCTAssertTrue(url.path.contains("/2026/06/"))
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".jpg"))
    }
}

// MARK: - Test helpers

private enum TestImageFactory {
    static func jpegData() -> Data {
        let image = makeSolidColorImage(width: 64, height: 64)
        let codec = ImageCodec()
        return (try? codec.encode(image: image, format: .jpeg).data) ?? Data()
    }

    static func makeSolidColorImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}
