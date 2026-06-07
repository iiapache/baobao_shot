import BabyCameraImageKit
import Database
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import BabyCameraCamera

final class ImportServiceTests: XCTestCase {
    private var tempDirectory: URL!
    private var originalsDirectory: URL!
    private var appDatabase: AppDatabase!
    private var importService: ImportService!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        originalsDirectory = tempDirectory.appendingPathComponent("originals", isDirectory: true)
        try FileManager.default.createDirectory(at: originalsDirectory, withIntermediateDirectories: true)
        appDatabase = try AppDatabase.makeInMemory()
        importService = makeImportService(dataByItemID: [:])
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        try await super.tearDown()
    }

    func testImportSuccessWritesFileAndInsertsPhoto() async throws {
        let takenAt = makeDate(year: 2024, month: 6, day: 15, hour: 14, minute: 30)
        let jpegData = try makeJPEGData(dateTimeOriginal: "2024:06:15 14:30:00")
        importService = makeImportService(dataByItemID: ["asset_1": jpegData])

        let result = try await importService.importPhoto(
            item: PickerImportItem(id: "asset_1"),
            request: makeRequest()
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
        XCTAssertEqual(result.takenAt, takenAt)

        let saved = try await appDatabase.makePhotoRepository().fetch(id: result.photoId)
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.babyIds, ["baby_1"])
        XCTAssertEqual(saved?.userId, "user_1")
        XCTAssertEqual(saved?.filePath, result.fileURL.path)
        XCTAssertTrue(saved?.exifJSON?.contains("\"baby_1\":167") == true)
    }

    func testImportRejectsMissingEXIF() async throws {
        let plainData = try makePlainJPEGData()
        importService = makeImportService(dataByItemID: ["asset_1": plainData])

        do {
            _ = try await importService.importPhoto(
                item: PickerImportItem(id: "asset_1"),
                request: makeRequest()
            )
            XCTFail("Expected missingEXIF")
        } catch {
            XCTAssertEqual(error as? ImportError, .missingEXIF)
        }

        let photos = try await appDatabase.makePhotoRepository().fetchByBaby(babyId: "baby_1", limit: 10)
        XCTAssertTrue(photos.isEmpty)
    }

    func testImportRejectsBeforeBirthDate() async throws {
        let jpegData = try makeJPEGData(dateTimeOriginal: "2023:12:31 10:00:00")
        importService = makeImportService(dataByItemID: ["asset_1": jpegData])

        do {
            _ = try await importService.importPhoto(
                item: PickerImportItem(id: "asset_1"),
                request: makeRequest(birthDate: "2024-01-01")
            )
            XCTFail("Expected beforeBirthDate")
        } catch {
            XCTAssertEqual(error as? ImportError, .beforeBirthDate)
        }

        let photos = try await appDatabase.makePhotoRepository().fetchByBaby(babyId: "baby_1", limit: 10)
        XCTAssertTrue(photos.isEmpty)
    }

    func testImportAllowsPhotoOnBirthDate() async throws {
        let jpegData = try makeJPEGData(dateTimeOriginal: "2024:01:01 08:00:00")
        importService = makeImportService(dataByItemID: ["asset_1": jpegData])

        let result = try await importService.importPhoto(
            item: PickerImportItem(id: "asset_1"),
            request: makeRequest(birthDate: "2024-01-01")
        )

        XCTAssertEqual(result.takenAt, makeDate(year: 2024, month: 1, day: 1, hour: 8))

        let saved = try await appDatabase.makePhotoRepository().fetch(id: result.photoId)
        XCTAssertNotNil(saved)
        XCTAssertTrue(saved?.exifJSON?.contains("\"baby_1\":1") == true)
    }

    func testImportRejectsEmptyBabyIds() async throws {
        let jpegData = try makeJPEGData(dateTimeOriginal: "2024:06:15 14:30:00")
        importService = makeImportService(dataByItemID: ["asset_1": jpegData])

        do {
            _ = try await importService.importPhoto(
                item: PickerImportItem(id: "asset_1"),
                request: ImportRequest(babyIds: [], babies: [], userId: "user_1")
            )
            XCTFail("Expected emptyBabyIds")
        } catch {
            XCTAssertEqual(error as? ImportError, .emptyBabyIds)
        }
    }

    func testBatchImportCollectsSuccessAndFailures() async throws {
        let validData = try makeJPEGData(dateTimeOriginal: "2024:06:15 14:30:00")
        let missingEXIFData = try makePlainJPEGData()
        let beforeBirthData = try makeJPEGData(dateTimeOriginal: "2023:06:15 14:30:00")

        importService = makeImportService(dataByItemID: [
            "valid": validData,
            "missing": missingEXIFData,
            "before": beforeBirthData,
        ])

        let batch = try await importService.importPhotos(
            items: [
                PickerImportItem(id: "valid"),
                PickerImportItem(id: "missing"),
                PickerImportItem(id: "before"),
            ],
            request: makeRequest(birthDate: "2024-01-01")
        )

        XCTAssertEqual(batch.succeeded.count, 1)
        XCTAssertEqual(batch.failed.count, 2)
        XCTAssertEqual(batch.failed.map(\.error), [.missingEXIF, .beforeBirthDate])

        let photos = try await appDatabase.makePhotoRepository().fetchByBaby(babyId: "baby_1", limit: 10)
        XCTAssertEqual(photos.count, 1)
    }

    func testDetectFormatFromJPEGAndHEIC() throws {
        let jpegData = try makePlainJPEGData()
        XCTAssertEqual(ImportService.detectFormat(from: jpegData), .jpeg)
    }

    // MARK: - Helpers

    private func makeImportService(dataByItemID: [String: Data]) -> ImportService {
        ImportService(
            pickerLoader: MockPickerItemLoader(dataByItemID: dataByItemID),
            metadataWriter: MetadataWriter(photoRepository: appDatabase.makePhotoRepository()),
            fileWriter: PhotoFileWriter(baseDirectory: originalsDirectory)
        )
    }

    private func makeRequest(birthDate: String = "2024-01-01") -> ImportRequest {
        ImportRequest(
            babyIds: ["baby_1"],
            babies: [BabyMetadataInput(id: "baby_1", birthDate: birthDate)],
            userId: "user_1"
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

    private func makePlainJPEGData() throws -> Data {
        let codec = ImageCodec()
        let image = makeSolidColorImage(width: 64, height: 64)
        return try codec.encode(image: image, format: .jpeg).data
    }

    private func makeJPEGData(dateTimeOriginal: String) throws -> Data {
        let codec = ImageCodec()
        let image = makeSolidColorImage(width: 64, height: 64)
        var data = try codec.encode(image: image, format: .jpeg).data

        let metadata: [String: Any] = [
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifDateTimeOriginal as String: dateTimeOriginal,
            ],
        ]

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

        return output as Data
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
