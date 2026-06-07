import BabyCameraImageKit
import XCTest
@testable import BabyCameraCamera

final class BurstCaptureTests: XCTestCase {
    private var tempDirectory: URL!
    private var mockOutput: MockPhotoOutput!
    private var mockPreset: MockSessionPresetController!
    private var pipeline: PhotoCapturePipeline!
    private var burst: BurstCapture!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        mockOutput = MockPhotoOutput()
        mockOutput.simulatedLatency = 0
        mockOutput.imageDataProvider = { PhotoCapturePipelineTestsHelper.validJPEG() }
        mockPreset = MockSessionPresetController()
        pipeline = PhotoCapturePipeline(
            photoOutput: mockOutput,
            codec: ImageCodec(),
            fileWriter: PhotoFileWriter(baseDirectory: tempDirectory)
        )
        burst = BurstCapture(
            pipeline: pipeline,
            sessionPresetController: mockPreset,
            clock: ImmediateBurstClock()
        )
    }

    override func tearDown() {
        _ = burst.stopBurst()
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testBurstSwitchesToHighPreset() throws {
        try burst.startBurst(maxFrames: 3)
        XCTAssertEqual(mockPreset.presetChanges.first, .high)
    }

    func testBurstCapturesTargetFrameCount() async throws {
        try burst.startBurst(maxFrames: 10)

        for _ in 0 ..< 100 {
            if !burst.isActive { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        XCTAssertFalse(burst.isActive)
        XCTAssertEqual(burst.capturedPhotos.count, 10)
        XCTAssertTrue(mockPreset.presetChanges.contains(.high))
        XCTAssertEqual(mockPreset.currentSessionPreset, .photo)
    }

    func testBurstMeetsTargetFrameRateWithImmediateClock() async throws {
        let frameCount = 10
        let startedAt = CFAbsoluteTimeGetCurrent()
        try burst.startBurst(maxFrames: frameCount)

        for _ in 0 ..< 100 {
            if !burst.isActive { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        let duration = CFAbsoluteTimeGetCurrent() - startedAt
        let measurement = PhotoCaptureBenchmark.measureBurst(
            frameCount: burst.capturedPhotos.count,
            durationSeconds: duration
        )
        XCTAssertEqual(measurement.frameCount, frameCount)
        XCTAssertTrue(measurement.meetsTarget)
    }

    func testStopBurstRestoresPhotoPreset() async throws {
        try burst.startBurst(maxFrames: nil)
        try await Task.sleep(nanoseconds: 20_000_000)
        _ = burst.stopBurst()
        XCTAssertEqual(mockPreset.currentSessionPreset, .photo)
    }

    func testStartBurstWhileActiveThrows() throws {
        try burst.startBurst(maxFrames: 5)
        XCTAssertThrowsError(try burst.startBurst(maxFrames: 3)) { error in
            XCTAssertEqual(error as? PhotoCaptureError, .captureInProgress)
        }
    }

    func testBurstTargetIntervalMatchesTenFPS() {
        XCTAssertEqual(BurstCapture.targetIntervalSeconds, 0.1, accuracy: 0.001)
        XCTAssertEqual(PhotoCaptureBenchmark.burstTargetFramesPerSecond, 10)
    }
}
