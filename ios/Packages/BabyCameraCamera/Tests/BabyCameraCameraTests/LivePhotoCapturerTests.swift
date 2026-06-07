import BabyCameraImageKit
import XCTest
@testable import BabyCameraCamera

final class LivePhotoCapturerTests: XCTestCase {
    private var tempDirectory: URL!
    private var mockOutput: MockPhotoOutput!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        mockOutput = MockPhotoOutput()
        mockOutput.imageDataProvider = { Data([0xFF, 0xD8, 0xFF, 0xE0]) }
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testConfigureOutputEnablesLivePhoto() throws {
        let capturer = LivePhotoCapturer(movieDirectory: tempDirectory)
        try capturer.configureOutput(mockOutput)
        XCTAssertTrue(mockOutput.isLivePhotoCaptureEnabled)
    }

    func testConfigureOutputThrowsWhenUnsupported() {
        mockOutput.isLivePhotoCaptureSupported = false
        let capturer = LivePhotoCapturer(movieDirectory: tempDirectory)

        XCTAssertThrowsError(try capturer.configureOutput(mockOutput)) { error in
            XCTAssertEqual(error as? PhotoCaptureError, .livePhotoUnsupported)
        }
    }

    func testMakeRequestIncludesMovieURL() throws {
        let movieDir = tempDirectory.appendingPathComponent("live", isDirectory: true)
        let capturer = LivePhotoCapturer(movieDirectory: movieDir)
        let request = try capturer.makeRequest(preferences: .default, flashMode: .on)

        XCTAssertTrue(request.isLivePhoto)
        XCTAssertEqual(request.flashMode, .on)
        XCTAssertNotNil(request.livePhotoMovieURL)
        XCTAssertEqual(request.livePhotoMovieURL?.pathExtension, "mov")
    }

    func testCaptureLivePhotoReturnsMovieURL() async throws {
        mockOutput.imageDataProvider = { PhotoCapturePipelineTestsHelper.validJPEG() }
        let movieDir = tempDirectory.appendingPathComponent("live", isDirectory: true)
        let capturer = LivePhotoCapturer(movieDirectory: movieDir)
        let pipeline = PhotoCapturePipeline(
            photoOutput: mockOutput,
            codec: ImageCodec(),
            fileWriter: PhotoFileWriter(baseDirectory: tempDirectory)
        )

        let result = try await pipeline.captureLivePhoto(capturer: capturer)

        XCTAssertNotNil(result.livePhotoMovieURL)
        XCTAssertTrue(mockOutput.isLivePhotoCaptureEnabled)
        XCTAssertEqual(mockOutput.lastRequest?.isLivePhoto, true)
    }
}

enum PhotoCapturePipelineTestsHelper {
    static func validJPEG() -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let image = context.makeImage()!
        return try! ImageCodec().encode(image: image, format: .jpeg).data
    }
}
