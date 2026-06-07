import CoreGraphics
import XCTest
@testable import BabyCameraWatermark

final class BrandWatermarkLayoutTests: XCTestCase {
    func testAnchorIsBottomLeft() {
        XCTAssertEqual(BrandWatermarkLayout.anchor, .bottomLeft)
    }

    func testLayoutRatioConstants() {
        XCTAssertEqual(BrandWatermarkLayout.marginRatio, 0.024, accuracy: 0.0001)
        XCTAssertEqual(BrandWatermarkLayout.fontSizeRatio, 0.022, accuracy: 0.0001)
        XCTAssertEqual(BrandWatermarkLayout.textOpacity, 0.72, accuracy: 0.0001)
    }

    func testBrandText() {
        XCTAssertEqual(BrandWatermarkLayout.brandText, "宝宝成长相机")
    }

    func testTextOriginStaysInBottomLeftCorner() {
        let canvas = CGSize(width: 1080, height: 1920)
        let origin = BrandWatermarkLayout.textOrigin(canvasSize: canvas)
        let margin = BrandWatermarkLayout.margin(for: canvas)
        let fontSize = BrandWatermarkLayout.fontSize(for: canvas)
        let textSize = BrandWatermarkLayout.measuredTextSize(fontSize: fontSize)

        XCTAssertEqual(origin.x, margin, accuracy: 0.5)
        XCTAssertEqual(origin.y, canvas.height - margin - textSize.height, accuracy: 0.5)
        XCTAssertLessThan(origin.x, canvas.width * 0.2)
        XCTAssertGreaterThan(origin.y, canvas.height * 0.8)
    }

    func testCITextOriginUsesBottomLeftMargin() {
        let canvas = CGSize(width: 640, height: 480)
        let origin = BrandWatermarkLayout.ciTextOrigin(canvasSize: canvas)
        let margin = BrandWatermarkLayout.margin(for: canvas)

        XCTAssertEqual(origin.x, margin, accuracy: 0.5)
        XCTAssertEqual(origin.y, margin, accuracy: 0.5)
    }

    func testFontSizeScalesWithShortEdge() {
        let small = BrandWatermarkLayout.fontSize(for: CGSize(width: 400, height: 300))
        let large = BrandWatermarkLayout.fontSize(for: CGSize(width: 4000, height: 3000))
        XCTAssertEqual(large / small, 10, accuracy: 0.01)
    }
}
