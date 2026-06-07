import XCTest
@testable import BabyCameraEditor

final class TileLayoutTests: XCTestCase {
    func testSmallImageUsesSingleTile() {
        let layout = TileLayout.compute(outputWidth: 1024, outputHeight: 768)

        XCTAssertEqual(layout.outputWidth, 1024)
        XCTAssertEqual(layout.outputHeight, 768)
        XCTAssertEqual(layout.tileCount, 1)
        XCTAssertFalse(layout.usesTiling)
    }

    func testLargeImageUsesMultipleTiles() {
        let layout = TileLayout.compute(outputWidth: 8000, outputHeight: 6000)

        XCTAssertEqual(layout.outputWidth, 8000)
        XCTAssertEqual(layout.outputHeight, 6000)
        XCTAssertGreaterThan(layout.tileCount, 1)
        XCTAssertTrue(layout.usesTiling)
    }

    func testOutputClampedToMaxExportDimension() {
        let layout = TileLayout.compute(outputWidth: 9000, outputHeight: 12000)

        XCTAssertEqual(layout.outputWidth, EditorRenderConfiguration.defaultMaxExportDimension)
        XCTAssertEqual(layout.outputHeight, EditorRenderConfiguration.defaultMaxExportDimension)
    }

    func testMaxTileDimensionRespectsMemoryBudget() {
        let config = EditorRenderConfiguration(maxMemoryBytes: 200 * 1024 * 1024)
        let maxTile = TileLayout.maxTileDimension(for: config)

        let tilePixels = maxTile * maxTile
        let estimatedBytes = tilePixels * 4 * 4
        XCTAssertLessThanOrEqual(estimatedBytes, config.maxMemoryBytes)
        XCTAssertGreaterThan(maxTile, 512)
    }

    func testTileRectsCoverFullOutputWithoutOverlapGaps() {
        let layout = TileLayout.compute(outputWidth: 8000, outputHeight: 8000)
        var covered = Array(repeating: Array(repeating: false, count: layout.outputWidth), count: layout.outputHeight)

        for row in 0..<layout.rowCount {
            for column in 0..<layout.columnCount {
                let rect = layout.tileRect(column: column, row: row)
                XCTAssertGreaterThan(rect.width, 0)
                XCTAssertGreaterThan(rect.height, 0)

                for y in Int(rect.origin.y)..<Int(rect.origin.y + rect.height) {
                    for x in Int(rect.origin.x)..<Int(rect.origin.x + rect.width) {
                        covered[y][x] = true
                    }
                }
            }
        }

        XCTAssertTrue(covered.flatMap { $0 }.allSatisfy { $0 })
    }

    func testTileBufferBytesMatchesRectArea() {
        let layout = TileLayout.compute(outputWidth: 5000, outputHeight: 4000)
        let rect = layout.tileRect(column: 0, row: 0)
        let expected = Int(rect.width) * Int(rect.height) * 4

        XCTAssertEqual(layout.tileBufferBytes(for: rect), expected)
    }

    func testTighterMemoryBudgetIncreasesTileCount() {
        let generous = TileLayout.compute(
            outputWidth: 8000,
            outputHeight: 8000,
            configuration: EditorRenderConfiguration(maxMemoryBytes: 200 * 1024 * 1024)
        )
        let tight = TileLayout.compute(
            outputWidth: 8000,
            outputHeight: 8000,
            configuration: EditorRenderConfiguration(maxMemoryBytes: 64 * 1024 * 1024)
        )

        XCTAssertGreaterThan(tight.tileCount, generous.tileCount)
    }
}
