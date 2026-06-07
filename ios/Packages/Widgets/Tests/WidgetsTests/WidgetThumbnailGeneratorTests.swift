import ImageIO
import XCTest
@testable import Widgets

final class WidgetThumbnailGeneratorTests: XCTestCase {
    private let generator = WidgetThumbnailGenerator()

    func testSmallThumbnailScalesDownLargeImage() throws {
        let source = WidgetTestImageFactory.makeJPEGData(width: 2400, height: 1800)
        let thumbnail = try generator.generateJPEG(from: source, size: .small)
        let dimensions = try decodedDimensions(from: thumbnail)

        XCTAssertLessThanOrEqual(max(dimensions.width, dimensions.height), WidgetThumbnailSize.small.maxEdgeLength)
    }

    func testLargeThumbnailScalesDownLargeImage() throws {
        let source = WidgetTestImageFactory.makeJPEGData(width: 4000, height: 3000)
        let thumbnail = try generator.generateJPEG(from: source, size: .large)
        let dimensions = try decodedDimensions(from: thumbnail)

        XCTAssertLessThanOrEqual(max(dimensions.width, dimensions.height), WidgetThumbnailSize.large.maxEdgeLength)
    }

    func testThumbnailPreservesAspectRatio() throws {
        let source = WidgetTestImageFactory.makeJPEGData(width: 1600, height: 900)
        let thumbnail = try generator.generateJPEG(from: source, size: .small)
        let dimensions = try decodedDimensions(from: thumbnail)

        let sourceRatio = 1600.0 / 900.0
        let thumbRatio = Double(dimensions.width) / Double(dimensions.height)
        XCTAssertEqual(sourceRatio, thumbRatio, accuracy: 0.02)
    }

    func testThumbnailSizeMatchesPRDSpec() {
        XCTAssertEqual(WidgetThumbnailSize.small.maxEdgeLength, 200)
        XCTAssertEqual(WidgetThumbnailSize.large.maxEdgeLength, 600)
    }

    private func decodedDimensions(from data: Data) throws -> (width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw WidgetError.thumbnailGenerationFailed
        }
        return (width, height)
    }
}
