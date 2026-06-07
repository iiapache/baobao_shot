import BabyCameraImageKit
import CoreGraphics
import CoreImage
import XCTest
@testable import BabyCameraEditor

final class EditorExportServiceTests: XCTestCase {
    func testExportJPEGUsesCodec() throws {
        let renderer = MockEditorRenderer(outputSize: CGSize(width: 320, height: 240))
        let codec = MockImageCodec()
        let service = EditorExportService(renderer: renderer, codec: codec)

        let state = EditorState()
        state.append(FilterStep(filterID: .mono))

        let result = try service.export(
            baseImage: CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 320, height: 240)),
            editorState: state,
            options: EditorExportOptions(format: .jpeg, quality: 0.9)
        )

        XCTAssertEqual(result.format, .jpeg)
        XCTAssertEqual(codec.lastFormat, .jpeg)
        XCTAssertEqual(codec.lastQuality, 0.9)
        XCTAssertEqual(renderer.lastStepCount, 1)
    }

    func testExportHEICRequestsHEICFormat() throws {
        let renderer = MockEditorRenderer(outputSize: CGSize(width: 128, height: 128))
        let codec = MockImageCodec()
        let service = EditorExportService(renderer: renderer, codec: codec)

        let result = try service.export(
            baseImage: CIImage(color: .blue).cropped(to: CGRect(x: 0, y: 0, width: 128, height: 128)),
            editorState: EditorState(),
            options: EditorExportOptions(format: .heic)
        )

        XCTAssertEqual(codec.lastFormat, .heic)
        XCTAssertEqual(result.format, .heic)
    }

    func testExportToFileWritesData() throws {
        let renderer = MockEditorRenderer(outputSize: CGSize(width: 64, height: 64))
        let codec = MockImageCodec()
        let service = EditorExportService(renderer: renderer, codec: codec)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("editor-export-\(UUID().uuidString).jpg")

        defer { try? FileManager.default.removeItem(at: outputURL) }

        let exportResult = try service.exportToFile(
            baseImage: CIImage(color: .green).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64)),
            editorState: EditorState(),
            options: EditorExportOptions(format: .jpeg),
            outputURL: outputURL
        )

        XCTAssertEqual(exportResult.outputURL, outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertGreaterThan(try Data(contentsOf: outputURL).count, 0)
    }

    func testFileExtensionForEncodedImage() {
        let jpeg = EncodedImage(data: Data([0x01]), format: .jpeg)
        let heic = EncodedImage(data: Data([0x01]), format: .heic)

        XCTAssertEqual(EditorExportService.fileExtension(for: jpeg), "jpg")
        XCTAssertEqual(EditorExportService.fileExtension(for: heic), "heic")
    }

    func testRenderConfigurationExposedFromService() throws {
        let config = EditorRenderConfiguration(maxExportDimension: 4096)
        let renderer = MockEditorRenderer(outputSize: CGSize(width: 10, height: 10))
        let service = EditorExportService(renderer: renderer, codec: MockImageCodec(), configuration: config)

        XCTAssertEqual(service.renderConfiguration.maxExportDimension, 4096)
    }
}

// MARK: - Mocks

private final class MockEditorRenderer: EditorRendering, @unchecked Sendable {
    let outputSize: CGSize
    private(set) var lastStepCount = 0

    init(outputSize: CGSize) {
        self.outputSize = outputSize
    }

    func render(baseImage: CIImage, steps: [AnyEditStep]) -> CIImage {
        lastStepCount = steps.count
        return baseImage
    }

    func renderToCGImage(baseImage: CIImage, editorState: EditorState) throws -> CGImage {
        lastStepCount = editorState.stepCount
        return Self.makeSolidImage(size: outputSize)
    }

    private static func makeSolidImage(size: CGSize) -> CGImage {
        let width = Int(size.width)
        let height = Int(size.height)
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
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}

private final class MockImageCodec: ImageCodecProtocol, @unchecked Sendable {
    private(set) var lastFormat: ImageFormat?
    private(set) var lastQuality: CGFloat?

    func isHEICSupported() -> Bool { true }

    func decode(data: Data) throws -> CGImage {
        try ImageCodec().decode(data: data)
    }

    func encode(image: CGImage, format: ImageFormat, quality: CGFloat) throws -> EncodedImage {
        lastFormat = format
        lastQuality = quality
        return EncodedImage(data: Data([0xFF, 0xD8, 0xFF, 0xD9]), format: format)
    }
}
