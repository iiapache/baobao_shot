import BabyCameraImageKit
import CoreGraphics
import XCTest
@testable import BabyCameraWatermark

final class WatermarkRendererTests: XCTestCase {
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

    func testRendererDelegatesPolicyForSubscriptionStates() {
        let renderer = WatermarkRenderer(
            policy: SubscriptionBrandWatermarkPolicy(brandWatermarkEnabled: { false })
        )
        XCTAssertTrue(renderer.shouldShowBrandWatermark(isSubscribed: false))
        XCTAssertFalse(renderer.shouldShowBrandWatermark(isSubscribed: true))
    }

    func testRenderSkipsBrandWatermarkForSubscribedUserWhenDisabled() throws {
        let sourceURL = try writeSolidImage(named: "source.jpg", format: .jpeg)
        let destinationURL = tempDirectory.appendingPathComponent("output.jpg")
        let renderer = WatermarkRenderer(
            policy: SubscriptionBrandWatermarkPolicy(brandWatermarkEnabled: { false })
        )

        let resultURL = try renderer.render(
            sourceFileURL: sourceURL,
            format: .jpeg,
            isSubscribed: true,
            destinationURL: destinationURL
        )

        let source = try codec.decode(data: Data(contentsOf: sourceURL))
        let output = try codec.decode(data: Data(contentsOf: resultURL))
        XCTAssertEqual(source.width, output.width)
        XCTAssertEqual(source.height, output.height)
        XCTAssertEqual(
            pixelDigest(of: source, corner: .bottomLeft),
            pixelDigest(of: output, corner: .bottomLeft)
        )
        XCTAssertEqual(
            pixelDigest(of: source, corner: .bottomRight),
            pixelDigest(of: output, corner: .bottomRight)
        )
    }

    func testRenderKeepsCameraCaptureWithoutDeepSynthesisBadge() throws {
        let sourceURL = try writeSolidImage(named: "camera.jpg", format: .jpeg)
        let destinationURL = tempDirectory.appendingPathComponent("camera-out.jpg")
        let renderer = WatermarkRenderer(policy: NeverShowBrandWatermarkPolicy())

        _ = try renderer.render(
            sourceFileURL: sourceURL,
            format: .jpeg,
            isSubscribed: true,
            destinationURL: destinationURL,
            options: .cameraCapture
        )

        let source = try codec.decode(data: Data(contentsOf: sourceURL))
        let output = try codec.decode(data: Data(contentsOf: destinationURL))
        XCTAssertEqual(
            pixelDigest(of: source, corner: .bottomRight),
            pixelDigest(of: output, corner: .bottomRight)
        )
    }

    func testRenderAlwaysAppliesDeepSynthesisBadgeForAIResult() throws {
        let sourceURL = try writeSolidImage(named: "source.jpg", format: .jpeg)
        let destinationURL = tempDirectory.appendingPathComponent("output-badge.jpg")
        let renderer = WatermarkRenderer(
            policy: NeverShowBrandWatermarkPolicy()
        )

        _ = try renderer.render(
            sourceFileURL: sourceURL,
            format: .jpeg,
            isSubscribed: true,
            destinationURL: destinationURL,
            options: .aiResult
        )

        let source = try codec.decode(data: Data(contentsOf: sourceURL))
        let output = try codec.decode(data: Data(contentsOf: destinationURL))
        XCTAssertNotEqual(
            pixelDigest(of: source, corner: .bottomRight),
            pixelDigest(of: output, corner: .bottomRight)
        )
        XCTAssertEqual(
            pixelDigest(of: source, corner: .bottomLeft),
            pixelDigest(of: output, corner: .bottomLeft)
        )
    }

    func testDrawDeepSynthesisBadgeChangesBottomRightPixels() throws {
        let source = TestImageFactory.makeSolidColorImage(width: 640, height: 480, color: .blue)
        let renderer = WatermarkRenderer()
        let output = try renderer.drawDeepSynthesisBadge(on: source)

        XCTAssertNotEqual(
            pixelDigest(of: source, corner: .bottomRight),
            pixelDigest(of: output, corner: .bottomRight)
        )
        XCTAssertEqual(
            pixelDigest(of: source, corner: .bottomLeft),
            pixelDigest(of: output, corner: .bottomLeft)
        )
    }

    func testDrawAllWatermarksRespectsInstantSubscriptionToggle() throws {
        let source = TestImageFactory.makeSolidColorImage(width: 640, height: 480, color: .blue)
        let renderer = WatermarkRenderer(policy: NeverShowBrandWatermarkPolicy())

        let subscribedOutput = try renderer.drawAllWatermarks(on: source, isSubscribed: true, options: .aiResult)
        let unsubscribedOutput = try renderer.drawAllWatermarks(on: source, isSubscribed: false, options: .aiResult)

        XCTAssertNotEqual(
            pixelDigest(of: subscribedOutput, corner: .bottomRight),
            pixelDigest(of: source, corner: .bottomRight)
        )
        XCTAssertEqual(
            pixelDigest(of: subscribedOutput, corner: .bottomLeft),
            pixelDigest(of: source, corner: .bottomLeft)
        )
        XCTAssertNotEqual(
            pixelDigest(of: unsubscribedOutput, corner: .bottomLeft),
            pixelDigest(of: source, corner: .bottomLeft)
        )
    }

    func testRenderAppliesWatermarkForNonSubscriber() throws {
        let sourceURL = try writeSolidImage(named: "source.jpg", format: .jpeg)
        let destinationURL = tempDirectory.appendingPathComponent("output.jpg")
        let renderer = WatermarkRenderer()

        _ = try renderer.render(
            sourceFileURL: sourceURL,
            format: .jpeg,
            isSubscribed: false,
            destinationURL: destinationURL
        )

        let source = try codec.decode(data: Data(contentsOf: sourceURL))
        let output = try codec.decode(data: Data(contentsOf: destinationURL))
        XCTAssertNotEqual(pixelDigest(of: source, corner: .bottomLeft), pixelDigest(of: output, corner: .bottomLeft))
    }

    func testDrawBrandWatermarkChangesBottomLeftPixels() throws {
        let source = TestImageFactory.makeSolidColorImage(width: 640, height: 480, color: .blue)
        let renderer = WatermarkRenderer(policy: AlwaysShowBrandWatermarkPolicy())
        let output = try renderer.drawBrandWatermark(on: source)

        XCTAssertNotEqual(
            pixelDigest(of: source, corner: .bottomLeft),
            pixelDigest(of: output, corner: .bottomLeft)
        )
        XCTAssertEqual(
            pixelDigest(of: source, corner: .topRight),
            pixelDigest(of: output, corner: .topRight)
        )
    }

    func testCompositeBrandWatermarkRespectsSubscriptionPolicy() throws {
        let base = CIImage(color: CIColor(red: 0.1, green: 0.2, blue: 0.9))
            .cropped(to: CGRect(x: 0, y: 0, width: 320, height: 240))
        let renderer = WatermarkRenderer(
            policy: SubscriptionBrandWatermarkPolicy(brandWatermarkEnabled: { false }),
            context: CIContext(options: [.useSoftwareRenderer: true])
        )

        let unchanged = renderer.compositeBrandWatermark(onto: base, isSubscribed: true)
        let unchangedCG = try XCTUnwrap(rendererContext(renderer).createCGImage(unchanged, from: unchanged.extent))

        let watermarked = renderer.compositeBrandWatermark(onto: base, isSubscribed: false)
        let watermarkedCG = try XCTUnwrap(rendererContext(renderer).createCGImage(watermarked, from: watermarked.extent))

        XCTAssertEqual(
            pixelDigest(of: unchangedCG, corner: .bottomLeft),
            pixelDigest(of: try XCTUnwrap(rendererContext(renderer).createCGImage(base, from: base.extent)), corner: .bottomLeft)
        )
        XCTAssertNotEqual(
            pixelDigest(of: watermarkedCG, corner: .bottomLeft),
            pixelDigest(of: unchangedCG, corner: .bottomLeft)
        )
    }

    private func rendererContext(_ renderer: WatermarkRenderer) -> CIContext {
        CIContext(options: [.useSoftwareRenderer: true])
    }

    // MARK: - Helpers

    private func writeSolidImage(named fileName: String, format: ImageFormat) throws -> URL {
        let image = TestImageFactory.makeSolidColorImage(width: 640, height: 480, color: .blue)
        let encoded = try codec.encode(image: image, format: format)
        let url = tempDirectory.appendingPathComponent(fileName)
        try encoded.data.write(to: url)
        return url
    }

    private enum ImageCorner {
        case bottomLeft
        case bottomRight
        case topRight
    }

    private func pixelDigest(of image: CGImage, corner: ImageCorner) -> UInt32 {
        let x: Int
        let y: Int
        switch corner {
        case .bottomLeft:
            x = 4
            y = image.height - 5
        case .bottomRight:
            x = image.width - 5
            y = image.height - 5
        case .topRight:
            x = image.width - 5
            y = 4
        }

        guard let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 0
        }

        let bytesPerPixel = image.bitsPerPixel / image.bitsPerComponent
        let bytesPerRow = image.bytesPerRow
        let offset = y * bytesPerRow + x * bytesPerPixel
        return UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])
    }
}

private enum TestImageFactory {
    static func makeSolidColorImage(
        width: Int,
        height: Int,
        color: CGColor
    ) -> CGImage {
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
    static var blue: CGColor {
        CGColor(red: 0.1, green: 0.2, blue: 0.9, alpha: 1)
    }
}
