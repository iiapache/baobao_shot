import BabyCameraImageKit
import BabyCameraWatermark
import CoreGraphics
import CoreImage
import UIKit
import XCTest
@testable import BabyCameraFamilyFeed

final class PostComposerWatermarkPreviewTests: XCTestCase {
    func testPreviewDelegatesToWatermarkRenderer() throws {
        let codec = ImageCodec()
        let sourceData = try makeSolidJPEGData(codec: codec)
        let spy = SpyWatermarkRenderer()
        let preview = PostComposerWatermarkPreview(renderer: spy, codec: codec)

        _ = try preview.previewCGImage(
            sourceData: sourceData,
            isSubscribed: false,
            includesDeepSynthesisBadge: true
        )

        XCTAssertEqual(spy.drawCallCount, 1)
        XCTAssertTrue(spy.lastOptions?.includeDeepSynthesisBadge == true)
    }

    func testPreviewRejectsEmptyData() {
        let preview = PostComposerWatermarkPreview()
        XCTAssertThrowsError(
            try preview.previewCGImage(
                sourceData: Data(),
                isSubscribed: false,
                includesDeepSynthesisBadge: false
            )
        ) { error in
            XCTAssertEqual(error as? PostWatermarkPreviewError, .emptySource)
        }
    }

    private func makeSolidJPEGData(codec: ImageCodec) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 16,
            height: 16,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "test", code: 1)
        }
        context.setFillColor(UIColor.blue.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        guard let image = context.makeImage() else {
            throw NSError(domain: "test", code: 2)
        }
        return try codec.encode(image: image, format: .jpeg).data
    }
}

private final class SpyWatermarkRenderer: WatermarkRendering, @unchecked Sendable {
    private(set) var drawCallCount = 0
    private(set) var lastOptions: WatermarkRenderOptions?

    func shouldShowBrandWatermark(isSubscribed: Bool) -> Bool { true }

    func compositeBrandWatermark(onto image: CIImage, isSubscribed: Bool) -> CIImage { image }

    func compositeDeepSynthesisBadge(onto image: CIImage) -> CIImage { image }

    func compositeAllWatermarks(
        onto image: CIImage,
        isSubscribed: Bool,
        options: WatermarkRenderOptions
    ) -> CIImage { image }

    func drawBrandWatermark(on image: CGImage) throws -> CGImage { image }

    func drawDeepSynthesisBadge(on image: CGImage) throws -> CGImage { image }

    func drawAllWatermarks(
        on image: CGImage,
        isSubscribed: Bool,
        options: WatermarkRenderOptions
    ) throws -> CGImage {
        drawCallCount += 1
        lastOptions = options
        return image
    }

    func render(
        sourceFileURL: URL,
        format: ImageFormat,
        isSubscribed: Bool,
        destinationURL: URL,
        options: WatermarkRenderOptions
    ) throws -> URL {
        sourceFileURL
    }
}
