import CoreGraphics
import XCTest
@testable import BabyCameraWatermark

final class DeepSynthesisBadgeLayoutTests: XCTestCase {
    func testAnchorIsBottomRight() {
        XCTAssertEqual(DeepSynthesisBadgeLayout.anchor, .bottomRight)
    }

    func testBadgeTextMatchesComplianceLabel() {
        XCTAssertEqual(DeepSynthesisBadgeLayout.badgeText, "AI 生成 · 深度合成")
    }

    func testWidthRatioWithinComplianceBand() {
        XCTAssertGreaterThanOrEqual(DeepSynthesisBadgeLayout.widthRatio, 0.05)
        XCTAssertLessThanOrEqual(DeepSynthesisBadgeLayout.widthRatio, 0.08)
    }

    func testBackgroundRectStaysInBottomRightCorner() {
        let canvas = CGSize(width: 1080, height: 1920)
        let rect = DeepSynthesisBadgeLayout.backgroundRect(canvasSize: canvas)
        let margin = DeepSynthesisBadgeLayout.margin(for: canvas)

        XCTAssertGreaterThan(rect.maxX, canvas.width * 0.7)
        XCTAssertGreaterThan(rect.maxY, canvas.height * 0.9)
        XCTAssertEqual(rect.maxX, canvas.width - margin, accuracy: 1)
        XCTAssertEqual(rect.maxY, canvas.height - margin, accuracy: 1)
    }

    func testTargetWidthScalesWithShortEdge() {
        let small = DeepSynthesisBadgeLayout.targetWidth(for: CGSize(width: 400, height: 300))
        let large = DeepSynthesisBadgeLayout.targetWidth(for: CGSize(width: 4000, height: 3000))
        XCTAssertEqual(large / small, 10, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(small / 300, 0.05)
        XCTAssertLessThanOrEqual(small / 300, 0.08)
    }
}
