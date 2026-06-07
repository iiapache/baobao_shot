import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import BabyCameraImageKit

final class EXIFReaderTests: XCTestCase {
    private let reader = EXIFReader()

    func testReadDateTimeOriginalFromJPEG() throws {
        let url = try writeJPEG(
            dateTimeOriginal: "2024:06:15 14:30:00",
            latitude: nil,
            longitude: nil
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let metadata = try reader.read(from: url)
        XCTAssertNotNil(metadata.dateTimeOriginal)

        let formatted = EXIFReader.exifDateTimeString(from: metadata.dateTimeOriginal!)
        XCTAssertEqual(formatted, "2024:06:15 14:30:00")
    }

    func testReadGPSFromJPEG() throws {
        let url = try writeJPEG(
            dateTimeOriginal: "2024:06:15 14:30:00",
            latitude: 39.9042,
            longitude: 116.4074
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let metadata = try reader.read(from: url)
        XCTAssertNotNil(metadata.latitude)
        XCTAssertNotNil(metadata.longitude)
        XCTAssertEqual(metadata.latitude!, 39.9042, accuracy: 0.0001)
        XCTAssertEqual(metadata.longitude!, 116.4074, accuracy: 0.0001)
    }

    func testReadJPEGWithoutEXIFReturnsEmptyMetadata() throws {
        let codec = ImageCodec()
        let image = TestImageFactory.makeSolidColorImage(width: 32, height: 32)
        let data = try codec.encode(image: image, format: .jpeg).data

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let metadata = try reader.read(from: url)
        XCTAssertNil(metadata.dateTimeOriginal)
        XCTAssertNil(metadata.latitude)
        XCTAssertNil(metadata.longitude)
        XCTAssertFalse(metadata.hasDateTimeOriginal)
    }

    func testReadMissingFileThrows() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).jpg")

        XCTAssertThrowsError(try reader.read(from: url)) { error in
            XCTAssertEqual(error as? ImageKitError, .invalidData)
        }
    }

    func testParseDateTimeOriginalHandlesNilAndEmpty() {
        XCTAssertNil(EXIFReader.parseDateTimeOriginal(nil))
        XCTAssertNil(EXIFReader.parseDateTimeOriginal(""))
    }

    // MARK: - Helpers

    private func writeJPEG(
        dateTimeOriginal: String,
        latitude: Double?,
        longitude: Double?
    ) throws -> URL {
        let codec = ImageCodec()
        let image = TestImageFactory.makeSolidColorImage(width: 64, height: 64)
        var data = try codec.encode(image: image, format: .jpeg).data

        var metadata: [String: Any] = [
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifDateTimeOriginal as String: dateTimeOriginal,
            ],
        ]

        if let latitude, let longitude {
            metadata[kCGImagePropertyGPSDictionary as String] = [
                kCGImagePropertyGPSLatitude as String: latitude,
                kCGImagePropertyGPSLatitudeRef as String: "N",
                kCGImagePropertyGPSLongitude as String: longitude,
                kCGImagePropertyGPSLongitudeRef as String: "E",
            ]
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ImageKitError.decodeFailed
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageKitError.encodeFailed
        }

        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageKitError.encodeFailed
        }

        data = output as Data
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try data.write(to: url)
        return url
    }
}

private enum TestImageFactory {
    static func makeSolidColorImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}
