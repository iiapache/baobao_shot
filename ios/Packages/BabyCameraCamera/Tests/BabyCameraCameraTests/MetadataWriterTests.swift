import BabyCameraImageKit
import Database
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import BabyCameraCamera

final class MetadataWriterTests: XCTestCase {
    private var tempDirectory: URL!
    private var appDatabase: AppDatabase!
    private var writer: MetadataWriter!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        appDatabase = try AppDatabase.makeInMemory()
        writer = MetadataWriter(photoRepository: appDatabase.makePhotoRepository())
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        try await super.tearDown()
    }

    func testWriteInsertsPhotoWithMergedEXIFAndGrowthDays() async throws {
        let takenAt = makeDate(year: 2024, month: 6, day: 15, hour: 14, minute: 30)
        let fileURL = try writeJPEG(dateTimeOriginal: "2024:06:15 14:30:00", at: tempDirectory)
        let photoOut = makePhotoOut(fileURL: fileURL, capturedAt: takenAt)

        let result = try await writer.write(
            MetadataWriteRequest(
                photoOut: photoOut,
                babyIds: ["baby_1", "baby_2"],
                babies: [
                    BabyMetadataInput(id: "baby_1", birthDate: "2024-01-01"),
                    BabyMetadataInput(id: "baby_2", birthDate: "2024-03-01"),
                ],
                userId: "user_1",
                location: PhotoLocation(latitude: 31.2, longitude: 121.5)
            )
        )

        XCTAssertEqual(result.photoId, photoOut.id.uuidString)
        XCTAssertEqual(result.mergedEXIF.babyIds, ["baby_1", "baby_2"])
        XCTAssertEqual(result.mergedEXIF.dateTimeOriginal, "2024:06:15 14:30:00")
        XCTAssertEqual(result.mergedEXIF.latitude, 31.2)
        XCTAssertEqual(result.mergedEXIF.longitude, 121.5)
        XCTAssertEqual(result.mergedEXIF.growthDays["baby_1"], 167)
        XCTAssertEqual(result.mergedEXIF.growthDays["baby_2"], 107)

        let saved = try await appDatabase.makePhotoRepository().fetch(id: result.photoId)
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.babyIds, ["baby_1", "baby_2"])
        XCTAssertEqual(saved?.userId, "user_1")
        XCTAssertEqual(saved?.lat, 31.2)
        XCTAssertEqual(saved?.lng, 121.5)
        XCTAssertTrue(saved?.localOnly == true)
        XCTAssertEqual(saved?.filePath, fileURL.path)
        XCTAssertFalse(saved?.sha256.isEmpty ?? true)
        XCTAssertTrue(saved?.exifJSON?.contains("\"baby_1\":167") == true)
    }

    func testWriteRejectsMissingEXIFWithoutFallback() async throws {
        let fileURL = try writePlainJPEG(at: tempDirectory)
        let photoOut = makePhotoOut(fileURL: fileURL, capturedAt: Date())

        do {
            _ = try await writer.write(
                MetadataWriteRequest(
                    photoOut: photoOut,
                    babyIds: ["baby_1"],
                    babies: [BabyMetadataInput(id: "baby_1", birthDate: "2024-01-01")],
                    userId: "user_1"
                )
            )
            XCTFail("Expected missingDateTimeOriginal")
        } catch {
            XCTAssertEqual(error as? MetadataError, .missingDateTimeOriginal)
        }

        let count = try await appDatabase.makePhotoRepository().fetchByBaby(babyId: "baby_1", limit: 10)
        XCTAssertTrue(count.isEmpty)
    }

    func testWriteUsesCaptureFallbackWhenFileEXIFMissing() async throws {
        let capturedAt = makeDate(year: 2024, month: 6, day: 15, hour: 10, minute: 0)
        let fileURL = try writePlainJPEG(at: tempDirectory)
        let photoOut = makePhotoOut(fileURL: fileURL, capturedAt: capturedAt)

        let result = try await writer.write(
            MetadataWriteRequest(
                photoOut: photoOut,
                babyIds: ["baby_1"],
                babies: [BabyMetadataInput(id: "baby_1", birthDate: "2024-01-01")],
                userId: "user_1",
                captureTakenAtFallback: capturedAt
            )
        )

        XCTAssertEqual(result.mergedEXIF.dateTimeOriginal, "2024:06:15 10:00:00")
        XCTAssertEqual(result.mergedEXIF.growthDays["baby_1"], 167)

        let saved = try await appDatabase.makePhotoRepository().fetch(id: result.photoId)
        XCTAssertNotNil(saved)
    }

    func testWriteRejectsEmptyBabyIds() async throws {
        let fileURL = try writeJPEG(dateTimeOriginal: "2024:06:15 14:30:00", at: tempDirectory)
        let photoOut = makePhotoOut(fileURL: fileURL, capturedAt: Date())

        do {
            _ = try await writer.write(
                MetadataWriteRequest(
                    photoOut: photoOut,
                    babyIds: [],
                    babies: [],
                    userId: "user_1"
                )
            )
            XCTFail("Expected emptyBabyIds")
        } catch {
            XCTAssertEqual(error as? MetadataError, .emptyBabyIds)
        }
    }

    func testWriteUsesFileGPSWhenLocationNotProvided() async throws {
        let fileURL = try writeJPEG(
            dateTimeOriginal: "2024:06:15 14:30:00",
            latitude: 39.9,
            longitude: 116.4,
            at: tempDirectory
        )
        let photoOut = makePhotoOut(fileURL: fileURL, capturedAt: Date())

        let result = try await writer.write(
            MetadataWriteRequest(
                photoOut: photoOut,
                babyIds: ["baby_1"],
                babies: [BabyMetadataInput(id: "baby_1", birthDate: "2024-01-01")],
                userId: "user_1"
            )
        )

        XCTAssertEqual(result.mergedEXIF.latitude!, 39.9, accuracy: 0.0001)
        XCTAssertEqual(result.mergedEXIF.longitude!, 116.4, accuracy: 0.0001)
    }

    func testOfflineWritePersistsToInMemoryDatabase() async throws {
        let fileURL = try writeJPEG(dateTimeOriginal: "2024:06:15 14:30:00", at: tempDirectory)
        let photoOut = makePhotoOut(fileURL: fileURL, capturedAt: Date())

        _ = try await writer.write(
            MetadataWriteRequest(
                photoOut: photoOut,
                babyIds: ["baby_1"],
                babies: [BabyMetadataInput(id: "baby_1", birthDate: "2024-01-01")],
                userId: "user_1"
            )
        )

        let byBaby = try await appDatabase.makePhotoRepository().fetchByBaby(babyId: "baby_1", limit: 10)
        XCTAssertEqual(byBaby.count, 1)
        XCTAssertEqual(byBaby.first?.id, photoOut.id.uuidString)
    }

    // MARK: - Helpers

    private func makePhotoOut(fileURL: URL, capturedAt: Date) -> PhotoOut {
        PhotoOut(
            id: UUID(),
            fileURL: fileURL,
            format: .jpeg,
            captureLatency: 0.05,
            didFallbackToJPEG: false
        )
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone.current
        return components.date!
    }

    private func writePlainJPEG(at directory: URL) throws -> URL {
        let codec = ImageCodec()
        let image = makeSolidColorImage(width: 64, height: 64)
        let data = try codec.encode(image: image, format: .jpeg).data
        let url = directory.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: url)
        return url
    }

    private func writeJPEG(
        dateTimeOriginal: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        at directory: URL
    ) throws -> URL {
        let codec = ImageCodec()
        let image = makeSolidColorImage(width: 64, height: 64)
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

        let url = directory.appendingPathComponent("\(UUID().uuidString).jpg")
        try (output as Data).write(to: url)
        return url
    }

    private func makeSolidColorImage(width: Int, height: Int) -> CGImage {
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
        context.setFillColor(CGColor(red: 0, green: 0.5, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}
