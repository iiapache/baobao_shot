import BabyCameraCamera
import BabyCameraImageKit
import XCTest
@testable import BabyCameraWatermark

final class CameraWatermarkHookIntegrationTests: XCTestCase {
    private let codec = ImageCodec()
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testMakeHookWritesWatermarkedFileForNonSubscriber() async throws {
        let sourceURL = try writeSolidImage(named: "capture.jpg")
        let hook = CameraWatermarkHooks.make(
            renderer: WatermarkRenderer(),
            isSubscribed: { false }
        )
        let request = CameraWatermarkRequest(
            sourceFileURL: sourceURL,
            overlayInfo: sampleOverlayInfo,
            format: .jpeg
        )

        let resultURL = try await hook(request)
        let expectedURL = CameraWatermarkHooks.watermarkedDestinationURL(for: request)

        XCTAssertEqual(resultURL, expectedURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))

        let sourceData = try Data(contentsOf: sourceURL)
        let outputData = try Data(contentsOf: resultURL)
        XCTAssertNotEqual(sourceData, outputData)
    }

    func testMakeHookPreservesSourceForSubscribedUserWhenDisabled() async throws {
        let sourceURL = try writeSolidImage(named: "capture.jpg")
        let hook = CameraWatermarkHooks.make(
            renderer: WatermarkRenderer(
                policy: SubscriptionBrandWatermarkPolicy(brandWatermarkEnabled: { false })
            ),
            isSubscribed: { true }
        )
        let request = CameraWatermarkRequest(
            sourceFileURL: sourceURL,
            overlayInfo: sampleOverlayInfo,
            format: .jpeg
        )

        let resultURL = try await hook(request)
        let source = try codec.decode(data: Data(contentsOf: sourceURL))
        let output = try codec.decode(data: Data(contentsOf: resultURL))
        XCTAssertEqual(source.width, output.width)
        XCTAssertEqual(source.height, output.height)
    }

    func testWatermarkedDestinationURLUsesFormatExtension() {
        let request = CameraWatermarkRequest(
            sourceFileURL: tempDirectory.appendingPathComponent("photo_123.heic"),
            overlayInfo: sampleOverlayInfo,
            format: .heic
        )

        let destination = CameraWatermarkHooks.watermarkedDestinationURL(for: request)
        XCTAssertEqual(destination.lastPathComponent, "photo_123_watermarked.heic")
    }

    // MARK: - Helpers

    private var sampleOverlayInfo: CameraOverlayInfo {
        CameraOverlayInfo(
            babyId: "bb_1",
            babyName: "豆豆",
            birthDate: "2024-01-15",
            displayAge: "出生第 6 天",
            ageDay: 6
        )
    }

    private func writeSolidImage(named fileName: String) throws -> URL {
        let image = TestImageFactory.makeSolidColorImage(width: 320, height: 240, color: .green)
        let encoded = try codec.encode(image: image, format: .jpeg)
        let url = tempDirectory.appendingPathComponent(fileName)
        try encoded.data.write(to: url)
        return url
    }
}

private enum TestImageFactory {
    static func makeSolidColorImage(width: Int, height: Int, color: CGColor) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}

private extension CGColor {
    static var green: CGColor {
        CGColor(red: 0.1, green: 0.8, blue: 0.2, alpha: 1)
    }
}
