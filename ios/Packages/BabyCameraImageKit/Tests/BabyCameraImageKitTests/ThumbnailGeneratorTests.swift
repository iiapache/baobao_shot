import XCTest
@testable import BabyCameraImageKit

final class ThumbnailGeneratorTests: XCTestCase {
    private let generator = ThumbnailGenerator()
    private let codec = ImageCodec()

    func testSmallThumbnailScalesDownLargeImage() throws {
        let source = TestImageFactory.makeSolidColorImage(width: 2048, height: 1536, color: .red)
        let thumbnail = try generator.generate(from: source, size: .small)

        XCTAssertLessThanOrEqual(max(thumbnail.width, thumbnail.height), ThumbnailSize.small.maxEdgeLength)
        XCTAssertGreaterThan(thumbnail.width, 0)
        XCTAssertGreaterThan(thumbnail.height, 0)
    }

    func testMediumThumbnailScalesDownLargeImage() throws {
        let source = TestImageFactory.makeSolidColorImage(width: 4000, height: 3000, color: .blue)
        let thumbnail = try generator.generate(from: source, size: .medium)

        XCTAssertLessThanOrEqual(max(thumbnail.width, thumbnail.height), ThumbnailSize.medium.maxEdgeLength)
    }

    func testThumbnailPreservesAspectRatio() throws {
        let source = TestImageFactory.makeSolidColorImage(width: 1600, height: 900, color: .green)
        let thumbnail = try generator.generate(from: source, size: .small)

        let sourceRatio = Double(source.width) / Double(source.height)
        let thumbRatio = Double(thumbnail.width) / Double(thumbnail.height)
        XCTAssertEqual(sourceRatio, thumbRatio, accuracy: 0.02)
    }

    func testThumbnailDoesNotUpscaleSmallImage() throws {
        let source = TestImageFactory.makeSolidColorImage(width: 200, height: 150, color: .yellow)
        let thumbnail = try generator.generate(from: source, size: .small)

        XCTAssertEqual(thumbnail.width, source.width)
        XCTAssertEqual(thumbnail.height, source.height)
    }

    func testGenerateDataFromJPEGProducesValidOutput() throws {
        let source = TestImageFactory.makeSolidColorImage(width: 3000, height: 2000, color: .white)
        let jpegData = try codec.encode(image: source, format: .jpeg).data

        let encoded = try generator.generateData(from: jpegData, size: .small, format: .jpeg)
        let decoded = try codec.decode(data: encoded.data)

        XCTAssertEqual(encoded.format, .jpeg)
        XCTAssertLessThanOrEqual(max(decoded.width, decoded.height), ThumbnailSize.small.maxEdgeLength)
    }

    func testGenerateDataMediumSize() throws {
        let source = TestImageFactory.makeSolidColorImage(width: 5000, height: 4000, color: .red)
        let jpegData = try codec.encode(image: source, format: .jpeg).data

        let encoded = try generator.generateData(from: jpegData, size: .medium, format: .jpeg)
        let decoded = try codec.decode(data: encoded.data)

        XCTAssertLessThanOrEqual(max(decoded.width, decoded.height), ThumbnailSize.medium.maxEdgeLength)
    }

    func testPortraitImageThumbnailLongestEdgeIs256() throws {
        let source = TestImageFactory.makeSolidColorImage(width: 1080, height: 1920, color: .blue)
        let thumbnail = try generator.generate(from: source, size: .small)

        XCTAssertEqual(max(thumbnail.width, thumbnail.height), 256)
    }

    func testLandscapeImageThumbnailLongestEdgeIs1024() throws {
        let source = TestImageFactory.makeSolidColorImage(width: 3840, height: 2160, color: .green)
        let thumbnail = try generator.generate(from: source, size: .medium)

        XCTAssertEqual(max(thumbnail.width, thumbnail.height), 1024)
    }

    func testThumbnailSizeEnumMatchesPRDSpec() {
        XCTAssertEqual(ThumbnailSize.small.maxEdgeLength, 256)
        XCTAssertEqual(ThumbnailSize.medium.maxEdgeLength, 1024)
        XCTAssertEqual(ThumbnailSize.allCases.count, 2)
    }

    func testGenerateDataHEICFormatWhenSupported() throws {
        guard codec.isHEICSupported() else {
            throw XCTSkip("HEIC encoding not supported on this platform")
        }

        let source = TestImageFactory.makeSolidColorImage(width: 2400, height: 1600, color: .red)
        let jpegData = try codec.encode(image: source, format: .jpeg).data

        let encoded = try generator.generateData(from: jpegData, size: .small, format: .heic)
        let decoded = try codec.decode(data: encoded.data)

        XCTAssertEqual(encoded.format, .heic)
        XCTAssertFalse(encoded.didFallbackToJPEG)
        XCTAssertLessThanOrEqual(max(decoded.width, decoded.height), ThumbnailSize.small.maxEdgeLength)
    }

    func testGenerateDataHEICFallbackToJPEG() throws {
        let fallbackGenerator = ThumbnailGenerator(codec: FallbackImageCodec())
        let source = TestImageFactory.makeSolidColorImage(width: 2000, height: 1500, color: .yellow)
        let jpegData = try codec.encode(image: source, format: .jpeg).data

        let encoded = try fallbackGenerator.generateData(from: jpegData, size: .medium, format: .heic)
        let decoded = try codec.decode(data: encoded.data)

        XCTAssertEqual(encoded.format, .jpeg)
        XCTAssertTrue(encoded.didFallbackToJPEG)
        XCTAssertLessThanOrEqual(max(decoded.width, decoded.height), ThumbnailSize.medium.maxEdgeLength)
    }
}

// MARK: - Fallback Codec

private struct FallbackImageCodec: ImageCodecProtocol {
    func isHEICSupported() -> Bool { false }

    func decode(data: Data) throws -> CGImage {
        try ImageCodec().decode(data: data)
    }

    func encode(
        image: CGImage,
        format: ImageFormat,
        quality: CGFloat
    ) throws -> EncodedImage {
        var inner = ImageCodec()
        switch format {
        case .jpeg:
            return try inner.encode(image: image, format: .jpeg, quality: quality)
        case .heic:
            let result = try inner.encode(image: image, format: .jpeg, quality: quality)
            return EncodedImage(data: result.data, format: .jpeg, didFallbackToJPEG: true)
        }
    }
}

// MARK: - Test Helpers

private enum TestImageFactory {
    enum Color {
        case red, green, blue, yellow, white
    }

    static func makeSolidColorImage(width: Int, height: Int, color: Color) -> CGImage {
        let components: [CGFloat]
        switch color {
        case .red: components = [1, 0, 0, 1]
        case .green: components = [0, 1, 0, 1]
        case .blue: components = [0, 0, 1, 1]
        case .yellow: components = [1, 1, 0, 1]
        case .white: components = [1, 1, 1, 1]
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let cgColor = CGColor(colorSpace: colorSpace, components: components)!
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}
