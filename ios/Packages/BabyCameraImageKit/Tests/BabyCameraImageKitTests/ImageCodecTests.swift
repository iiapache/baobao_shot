import XCTest
@testable import BabyCameraImageKit

final class ImageCodecTests: XCTestCase {
    private let codec = ImageCodec()

    func testDecodeEmptyDataThrowsInvalidData() {
        XCTAssertThrowsError(try codec.decode(data: Data())) { error in
            XCTAssertEqual(error as? ImageKitError, .invalidData)
        }
    }

    func testDecodeInvalidDataThrowsDecodeFailed() {
        XCTAssertThrowsError(try codec.decode(data: Data([0x00, 0x01, 0x02]))) { error in
            XCTAssertEqual(error as? ImageKitError, .decodeFailed)
        }
    }

    func testJPEGRoundTripPreservesDimensions() throws {
        let original = TestImageFactory.makeSolidColorImage(width: 640, height: 480, color: .red)
        let encoded = try codec.encode(image: original, format: .jpeg, quality: 0.92)
        let decoded = try codec.decode(data: encoded.data)

        XCTAssertEqual(encoded.format, .jpeg)
        XCTAssertFalse(encoded.didFallbackToJPEG)
        XCTAssertEqual(decoded.width, 640)
        XCTAssertEqual(decoded.height, 480)
    }

    func testHEICRoundTripWhenSupported() throws {
        guard codec.isHEICSupported() else {
            throw XCTSkip("HEIC encoding not supported on this platform")
        }

        let original = TestImageFactory.makeSolidColorImage(width: 800, height: 600, color: .blue)
        let encoded = try codec.encode(image: original, format: .heic, quality: 0.92)
        let decoded = try codec.decode(data: encoded.data)

        XCTAssertEqual(encoded.format, .heic)
        XCTAssertFalse(encoded.didFallbackToJPEG)
        XCTAssertEqual(decoded.width, 800)
        XCTAssertEqual(decoded.height, 600)
    }

    func testHEICFallbackToJPEGWhenUnsupported() throws {
        let fallbackCodec = FallbackImageCodec()
        let original = TestImageFactory.makeSolidColorImage(width: 400, height: 300, color: .green)
        let encoded = try fallbackCodec.encode(image: original, format: .heic, quality: 0.92)
        let decoded = try fallbackCodec.decode(data: encoded.data)

        XCTAssertEqual(encoded.format, .jpeg)
        XCTAssertTrue(encoded.didFallbackToJPEG)
        XCTAssertEqual(decoded.width, 400)
        XCTAssertEqual(decoded.height, 300)
    }

    func testRealCodecHEICFallbackOnUnsupportedPlatform() throws {
        guard !codec.isHEICSupported() else {
            throw XCTSkip("HEIC is supported on this platform; fallback covered by FallbackImageCodec mock")
        }

        let original = TestImageFactory.makeSolidColorImage(width: 320, height: 240, color: .green)
        let encoded = try codec.encode(image: original, format: .heic)
        let decoded = try codec.decode(data: encoded.data)

        XCTAssertEqual(encoded.format, .jpeg)
        XCTAssertTrue(encoded.didFallbackToJPEG)
        XCTAssertEqual(decoded.width, 320)
        XCTAssertEqual(decoded.height, 240)
    }

    func testJPEGToHEICToJPEGConversionChain() throws {
        let original = TestImageFactory.makeSolidColorImage(width: 512, height: 512, color: .yellow)
        let jpegData = try codec.encode(image: original, format: .jpeg).data
        let fromJPEG = try codec.decode(data: jpegData)

        if codec.isHEICSupported() {
            let heicEncoded = try codec.encode(image: fromJPEG, format: .heic)
            XCTAssertEqual(heicEncoded.format, .heic)
            let fromHEIC = try codec.decode(data: heicEncoded.data)
            let backToJPEG = try codec.encode(image: fromHEIC, format: .jpeg)
            XCTAssertEqual(backToJPEG.format, .jpeg)
            XCTAssertGreaterThan(backToJPEG.data.count, 0)
        } else {
            let fallbackEncoded = try codec.encode(image: fromJPEG, format: .heic)
            XCTAssertEqual(fallbackEncoded.format, .jpeg)
            XCTAssertTrue(fallbackEncoded.didFallbackToJPEG)
        }
    }

    func testEncodedJPEGHasValidMagicBytes() throws {
        let original = TestImageFactory.makeSolidColorImage(width: 100, height: 100, color: .white)
        let encoded = try codec.encode(image: original, format: .jpeg)

        XCTAssertEqual(encoded.data.prefix(2), Data([0xFF, 0xD8]))
    }

    func testDecodeJPEGDataRoundTrip() throws {
        let original = TestImageFactory.makeSolidColorImage(width: 128, height: 96, color: .red)
        let jpegData = try codec.encode(image: original, format: .jpeg).data
        let decoded = try codec.decode(data: jpegData)

        XCTAssertEqual(decoded.width, 128)
        XCTAssertEqual(decoded.height, 96)
    }

    func testDecodeHEICDataWhenSupported() throws {
        guard codec.isHEICSupported() else {
            throw XCTSkip("HEIC encoding not supported on this platform")
        }

        let original = TestImageFactory.makeSolidColorImage(width: 256, height: 256, color: .blue)
        let heicData = try codec.encode(image: original, format: .heic).data
        let decoded = try codec.decode(data: heicData)

        XCTAssertEqual(decoded.width, 256)
        XCTAssertEqual(decoded.height, 256)
    }

    func testImageFormatUTTypeIdentifiers() {
        XCTAssertEqual(ImageFormat.jpeg.utTypeIdentifier, "public.jpeg")
        XCTAssertEqual(ImageFormat.heic.utTypeIdentifier, "public.heic")
        XCTAssertEqual(ImageFormat.jpeg.fileExtension, "jpg")
        XCTAssertEqual(ImageFormat.heic.fileExtension, "heic")
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

/// 模拟 HEIC 不可用的编解码器，用于验证降级路径。
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
