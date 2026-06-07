import CoreGraphics
import CoreImage
import Darwin
import XCTest
@testable import BabyCameraEditor

final class TileRendererTests: XCTestCase {
    func testSingleTileRenderUsesCreateCGImage() throws {
        let mock = MockCIContextRenderer()
        let renderer = TileRenderer(context: mock)
        let image = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 512, height: 512))

        let output = try renderer.renderToCGImage(image)

        XCTAssertEqual(output.width, 512)
        XCTAssertEqual(output.height, 512)
        XCTAssertEqual(mock.createImageCallCount, 1)
        XCTAssertEqual(mock.renderCallCount, 0)
    }

    func testTiledRenderUsesBitmapRender() throws {
        let mock = MockCIContextRenderer()
        let tightConfig = EditorRenderConfiguration(
            maxExportDimension: 8000,
            maxMemoryBytes: 8 * 1024 * 1024,
            memoryOverheadBytes: 1 * 1024 * 1024
        )
        let renderer = TileRenderer(context: mock, configuration: tightConfig)
        let image = CIImage(color: .blue).cropped(to: CGRect(x: 0, y: 0, width: 4000, height: 3000))

        let output = try renderer.renderToCGImage(image)

        XCTAssertEqual(output.width, 4000)
        XCTAssertEqual(output.height, 3000)
        XCTAssertEqual(mock.createImageCallCount, 0)
        XCTAssertGreaterThan(mock.renderCallCount, 1)
    }

    func testInvalidExtentThrows() {
        let mock = MockCIContextRenderer()
        let renderer = TileRenderer(context: mock)
        let image = CIImage(color: .clear).cropped(to: CGRect(x: 0, y: 0, width: 0, height: 100))

        XCTAssertThrowsError(try renderer.renderToCGImage(image)) { error in
            XCTAssertEqual(error as? EditorRenderError, .invalidExtent)
        }
    }
}

private final class MockCIContextRenderer: CIContextRendering, @unchecked Sendable {
    private(set) var createImageCallCount = 0
    private(set) var renderCallCount = 0

    func createCGImage(
        _ image: CIImage,
        from rect: CGRect,
        format: CIFormat,
        colorSpace: CGColorSpace
    ) -> CGImage? {
        createImageCallCount += 1
        return Self.makeImage(width: Int(rect.width), height: Int(rect.height))
    }

    func render(
        _ image: CIImage,
        toBitmap data: UnsafeMutableRawPointer,
        rowBytes: Int,
        bounds: CGRect,
        format: CIFormat,
        colorSpace: CGColorSpace
    ) {
        renderCallCount += 1
        let width = Int(bounds.width)
        let height = Int(bounds.height)
        let fill = rowBytes * height
        memset(data, 0xFF, fill)
    }

    private static func makeImage(width: Int, height: Int) -> CGImage {
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
