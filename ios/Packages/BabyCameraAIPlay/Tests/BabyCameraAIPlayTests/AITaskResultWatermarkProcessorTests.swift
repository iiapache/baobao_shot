import BabyCameraImageKit
import BabyCameraVideoKit
import CoreGraphics
import Database
import Foundation
import XCTest
@testable import BabyCameraAIPlay
@testable import BabyCameraWatermark

final class AITaskResultWatermarkProcessorTests: XCTestCase {
    private let codec = ImageCodec()
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("AITaskResultWatermarkProcessor-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
    }

    func testApplyWatermarksToImageFileAlwaysAddsDeepSynthesisBadge() throws {
        let sourceURL = try writeSolidImage(named: "source.heic", format: .heic)
        let before = try codec.decode(data: Data(contentsOf: sourceURL))
        let processor = makeProcessor(policy: NeverShowBrandWatermarkPolicy())

        try processor.applyWatermarksToImageFile(at: sourceURL, isSubscribed: true)

        let after = try codec.decode(data: Data(contentsOf: sourceURL))
        XCTAssertNotEqual(
            pixelDigest(of: before, corner: .bottomRight),
            pixelDigest(of: after, corner: .bottomRight)
        )
    }

    func testApplyWatermarksUsesSubscriptionStateAtCallTime() throws {
        let subscribedURL = try writeSolidImage(named: "sub.heic", format: .heic)
        let unsubscribedURL = try writeSolidImage(named: "unsub.heic", format: .heic)
        let baseline = try codec.decode(data: Data(contentsOf: unsubscribedURL))
        let processor = makeProcessor(
            policy: SubscriptionBrandWatermarkPolicy(brandWatermarkEnabled: { false })
        )

        try processor.applyWatermarksToImageFile(at: subscribedURL, isSubscribed: true)
        try processor.applyWatermarksToImageFile(at: unsubscribedURL, isSubscribed: false)

        let subscribed = try codec.decode(data: Data(contentsOf: subscribedURL))
        let unsubscribed = try codec.decode(data: Data(contentsOf: unsubscribedURL))

        XCTAssertEqual(
            pixelDigest(of: subscribed, corner: .bottomLeft),
            pixelDigest(of: baseline, corner: .bottomLeft)
        )
        XCTAssertNotEqual(
            pixelDigest(of: unsubscribed, corner: .bottomLeft),
            pixelDigest(of: baseline, corner: .bottomLeft)
        )
    }

    func testGenerateVideoCoverThumbnailWritesWatermarkedFile() async throws {
        let frame = TestImageFactory.makeSolidColorImage(width: 640, height: 360, color: .green)
        let videoURL = tempRoot.appendingPathComponent("clip.mp4")
        try "video".write(to: videoURL, atomically: true, encoding: .utf8)

        let processor = AITaskResultWatermarkProcessor(
            storePaths: LocalStorePaths(storeRoot: tempRoot),
            renderer: WatermarkRenderer(),
            thumbnailExtractor: MockVideoThumbnailExtractor(frame: frame),
            thumbnailGenerator: ThumbnailGenerator(),
            codec: codec
        )

        let thumbnailPath = try await processor.generateVideoCoverThumbnail(
            videoURL: videoURL,
            derivedId: "tsk_video_thumb",
            isSubscribed: false
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbnailPath))
        XCTAssertTrue(thumbnailPath.contains("/thumbnails/tsk_video_thumb_256.heic"))

        let thumbnail = try codec.decode(data: Data(contentsOf: URL(fileURLWithPath: thumbnailPath)))
        XCTAssertLessThanOrEqual(max(thumbnail.width, thumbnail.height), 256)
    }

    private func makeProcessor(policy: any BrandWatermarkPolicy = SubscriptionBrandWatermarkPolicy()) -> AITaskResultWatermarkProcessor {
        AITaskResultWatermarkProcessor(
            storePaths: LocalStorePaths(storeRoot: tempRoot),
            renderer: WatermarkRenderer(policy: policy),
            codec: codec
        )
    }

    private func writeSolidImage(named fileName: String, format: ImageFormat) throws -> URL {
        let image = TestImageFactory.makeSolidColorImage(width: 640, height: 480, color: .blue)
        let encoded = try codec.encode(image: image, format: format)
        let url = tempRoot.appendingPathComponent(fileName)
        try encoded.data.write(to: url)
        return url
    }

    private func writeSolidImageData() throws -> Data {
        let image = TestImageFactory.makeSolidColorImage(width: 640, height: 480, color: .blue)
        return try codec.encode(image: image, format: .heic).data
    }

    private enum ImageCorner {
        case bottomLeft
        case bottomRight
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

private struct MockVideoThumbnailExtractor: VideoThumbnailExtracting {
    let frame: CGImage

    func extractThumbnail(from url: URL, at seconds: TimeInterval, maxEdgeLength: Int) async throws -> CGImage {
        frame
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
    static var blue: CGColor {
        CGColor(red: 0.1, green: 0.2, blue: 0.9, alpha: 1)
    }

    static var green: CGColor {
        CGColor(red: 0.1, green: 0.8, blue: 0.2, alpha: 1)
    }
}
