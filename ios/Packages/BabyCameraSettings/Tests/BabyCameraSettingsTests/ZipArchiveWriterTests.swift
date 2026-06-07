import XCTest
@testable import BabyCameraSettings

final class ZipArchiveWriterTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("zip-writer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testCreatesReadableZipArchive() throws {
        let sourceURL = tempDirectory.appendingPathComponent("photo.heic")
        try Data("original-image".utf8).write(to: sourceURL)

        let zipURL = tempDirectory.appendingPathComponent("export.zip")
        let writer = try ZipArchiveWriter(outputURL: zipURL)
        try writer.appendFile(at: sourceURL, zipPath: "photos/photo.heic")
        try writer.appendData(Data("{\"version\":1}".utf8), zipPath: "metadata.json")
        try writer.close()

        let archiveData = try Data(contentsOf: zipURL)
        XCTAssertGreaterThan(archiveData.count, 100)
        XCTAssertTrue(archiveData.starts(with: Data([0x50, 0x4B, 0x03, 0x04])))
        XCTAssertTrue(
            String(data: archiveData, encoding: .isoLatin1)?.contains("metadata.json") == true
        )
    }
}
