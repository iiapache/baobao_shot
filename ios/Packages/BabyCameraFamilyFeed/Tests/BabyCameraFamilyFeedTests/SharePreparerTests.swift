import BabyCameraImageKit
import BabyCameraVideoKit
import BabyCameraWatermark
import CoreGraphics
import Foundation
import XCTest
@testable import BabyCameraFamilyFeed

final class SharePreparerTests: XCTestCase {
    private let codec = ImageCodec()
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SharePreparer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
    }

    func testPrepareImageAppliesDeepSynthesisBadgeForAIContent() async throws {
        let sourceURL = try writeSolidImage(named: "ai.jpg", format: .jpeg)
        let before = try codec.decode(data: Data(contentsOf: sourceURL))
        let preparer = SharePreparer(renderer: WatermarkRenderer(policy: NeverShowBrandWatermarkPolicy()))

        let result = try await preparer.prepare(
            SharePreparationRequest(
                sourceURL: sourceURL,
                mediaKind: .image,
                isSubscribed: true,
                requiresDeepSynthesisBadge: true
            )
        )

        XCTAssertEqual(result.mediaKind, .image)
        XCTAssertNil(result.thumbnailURL)
        XCTAssertTrue(result.appliedDeepSynthesisBadge)
        XCTAssertFalse(result.appliedBrandWatermark)

        let after = try codec.decode(data: Data(contentsOf: result.mediaURL))
        XCTAssertNotEqual(
            pixelDigest(of: before, corner: .bottomRight),
            pixelDigest(of: after, corner: .bottomRight)
        )
    }

    func testPrepareImageRespectsSubscriptionForBrandWatermark() async throws {
        let subscribedURL = try writeSolidImage(named: "sub.jpg", format: .jpeg)
        let unsubscribedURL = try writeSolidImage(named: "unsub.jpg", format: .jpeg)
        let baseline = try codec.decode(data: Data(contentsOf: unsubscribedURL))
        let preparer = SharePreparer(
            renderer: WatermarkRenderer(
                policy: SubscriptionBrandWatermarkPolicy(brandWatermarkEnabled: { false })
            )
        )

        let subscribedResult = try await preparer.prepare(
            SharePreparationRequest(
                sourceURL: subscribedURL,
                mediaKind: .image,
                isSubscribed: true,
                requiresDeepSynthesisBadge: false
            )
        )
        let unsubscribedResult = try await preparer.prepare(
            SharePreparationRequest(
                sourceURL: unsubscribedURL,
                mediaKind: .image,
                isSubscribed: false,
                requiresDeepSynthesisBadge: false
            )
        )

        XCTAssertFalse(subscribedResult.appliedBrandWatermark)
        XCTAssertTrue(unsubscribedResult.appliedBrandWatermark)

        let subscribed = try codec.decode(data: Data(contentsOf: subscribedResult.mediaURL))
        let unsubscribed = try codec.decode(data: Data(contentsOf: unsubscribedResult.mediaURL))

        XCTAssertEqual(
            pixelDigest(of: subscribed, corner: .bottomLeft),
            pixelDigest(of: baseline, corner: .bottomLeft)
        )
        XCTAssertNotEqual(
            pixelDigest(of: unsubscribed, corner: .bottomLeft),
            pixelDigest(of: baseline, corner: .bottomLeft)
        )
    }

    func testPrepareVideoPassthroughByDefault() async throws {
        let videoURL = tempRoot.appendingPathComponent("clip.mp4")
        try Data("video".utf8).write(to: videoURL)
        let frame = TestImageFactory.makeSolidColorImage(width: 640, height: 360, color: .green)
        let preparer = SharePreparer(
            renderer: WatermarkRenderer(),
            thumbnailExtractor: MockVideoThumbnailExtractor(frame: frame)
        )

        let result = try await preparer.prepare(
            SharePreparationRequest(
                sourceURL: videoURL,
                mediaKind: .video,
                isSubscribed: false,
                requiresDeepSynthesisBadge: true
            )
        )

        XCTAssertEqual(result.mediaURL, videoURL)
        XCTAssertNotNil(result.thumbnailURL)
        XCTAssertTrue(result.appliedDeepSynthesisBadge)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.thumbnailURL!.path))
    }

    func testPrepareVideoReencodeUsesExporterWhenRequested() async throws {
        let videoURL = tempRoot.appendingPathComponent("clip.mp4")
        try Data("video".utf8).write(to: videoURL)
        let exportedURL = tempRoot.appendingPathComponent("exported.mp4")
        let frame = TestImageFactory.makeSolidColorImage(width: 640, height: 360, color: .green)
        let exporter = MockVideoExporter(destinationURL: exportedURL)
        let preparer = SharePreparer(
            renderer: WatermarkRenderer(),
            thumbnailExtractor: MockVideoThumbnailExtractor(frame: frame),
            videoExporter: exporter
        )

        let result = try await preparer.prepare(
            SharePreparationRequest(
                sourceURL: videoURL,
                mediaKind: .video,
                isSubscribed: false,
                requiresDeepSynthesisBadge: true,
                reencodeVideo: true
            )
        )

        XCTAssertEqual(exporter.exportCallCount, 1)
        XCTAssertEqual(result.mediaURL, exportedURL)
    }

    func testPreparePropagatesGateFailure() async {
        let preparer = SharePreparer()
        let request = SharePreparationRequest(
            sourceURL: tempRoot.appendingPathComponent("missing.jpg"),
            mediaKind: .image,
            isSubscribed: false,
            requiresDeepSynthesisBadge: false
        )

        do {
            _ = try await preparer.prepare(request)
            XCTFail("Expected gate failure")
        } catch let error as SharePreparerError {
            XCTAssertEqual(error, .gateFailed(.sourceMissing))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPrepareVideoThumbnailAppliesWatermarks() async throws {
        let videoURL = tempRoot.appendingPathComponent("clip.mp4")
        try Data("video".utf8).write(to: videoURL)
        let frame = TestImageFactory.makeSolidColorImage(width: 640, height: 360, color: .blue)
        let preparer = SharePreparer(
            renderer: WatermarkRenderer(policy: NeverShowBrandWatermarkPolicy()),
            thumbnailExtractor: MockVideoThumbnailExtractor(frame: frame)
        )

        let result = try await preparer.prepare(
            SharePreparationRequest(
                sourceURL: videoURL,
                mediaKind: .video,
                isSubscribed: true,
                requiresDeepSynthesisBadge: true
            )
        )

        let thumbnail = try codec.decode(data: Data(contentsOf: try XCTUnwrap(result.thumbnailURL)))
        XCTAssertNotEqual(
            pixelDigest(of: frame, corner: .bottomRight),
            pixelDigest(of: thumbnail, corner: .bottomRight)
        )
    }

    private func writeSolidImage(named fileName: String, format: ImageFormat) throws -> URL {
        let image = TestImageFactory.makeSolidColorImage(width: 640, height: 480, color: .blue)
        let encoded = try codec.encode(image: image, format: format)
        let url = tempRoot.appendingPathComponent(fileName)
        try encoded.data.write(to: url)
        return url
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

private final class MockVideoExporter: VideoExporting, @unchecked Sendable {
    let destinationURL: URL
    private(set) var exportCallCount = 0

    init(destinationURL: URL) {
        self.destinationURL = destinationURL
    }

    func export(
        sourceURL: URL,
        destinationURL: URL,
        configuration: VideoExportConfiguration,
        progressHandler: (@Sendable (Double) -> Void)?
    ) async throws -> URL {
        exportCallCount += 1
        try Data("exported".utf8).write(to: self.destinationURL)
        return self.destinationURL
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
