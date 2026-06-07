import CoreGraphics
import Foundation

/// 分块渲染布局：纯计算逻辑，便于单测验证。
public struct TileLayout: Equatable, Sendable {
    public let outputWidth: Int
    public let outputHeight: Int
    /// 单块边长（像素，正方形分块）。
    public let tileSize: Int
    public let columnCount: Int
    public let rowCount: Int

    public var tileCount: Int { columnCount * rowCount }
    public var usesTiling: Bool { tileCount > 1 }

    public init(
        outputWidth: Int,
        outputHeight: Int,
        tileSize: Int,
        columnCount: Int,
        rowCount: Int
    ) {
        self.outputWidth = outputWidth
        self.outputHeight = outputHeight
        self.tileSize = tileSize
        self.columnCount = columnCount
        self.rowCount = rowCount
    }

    /// 计算给定输出尺寸下的分块方案。
    public static func compute(
        outputWidth: Int,
        outputHeight: Int,
        configuration: EditorRenderConfiguration = .default
    ) -> TileLayout {
        let clampedWidth = min(max(outputWidth, 1), configuration.maxExportDimension)
        let clampedHeight = min(max(outputHeight, 1), configuration.maxExportDimension)
        let maxTileDimension = maxTileDimension(for: configuration)

        let columns = max(1, (clampedWidth + maxTileDimension - 1) / maxTileDimension)
        let rows = max(1, (clampedHeight + maxTileDimension - 1) / maxTileDimension)

        let tileWidth = (clampedWidth + columns - 1) / columns
        let tileHeight = (clampedHeight + rows - 1) / rows
        let tileSize = max(tileWidth, tileHeight, 1)

        return TileLayout(
            outputWidth: clampedWidth,
            outputHeight: clampedHeight,
            tileSize: tileSize,
            columnCount: columns,
            rowCount: rows
        )
    }

    /// 根据内存预算推导单块最大边长。
    public static func maxTileDimension(for configuration: EditorRenderConfiguration) -> Int {
        let available = max(configuration.maxMemoryBytes - configuration.memoryOverheadBytes, 1)
        let bytesPerPixel = 4
        // 单块 RGBA + CI 中间缓冲，保守按 4 倍估算。
        let ciWorkingMultiplier = 4
        let maxTilePixels = available / (bytesPerPixel * ciWorkingMultiplier)
        let maxDimension = Int(floor(sqrt(Double(maxTilePixels))))
        return max(maxDimension, 1)
    }

    /// 第 `(column, row)` 块在输出图像中的像素矩形（CI 坐标，原点左下）。
    public func tileRect(column: Int, row: Int) -> CGRect {
        precondition(column >= 0 && column < columnCount)
        precondition(row >= 0 && row < rowCount)

        let originX = column * tileSize
        let originY = row * tileSize
        let width = min(tileSize, outputWidth - originX)
        let height = min(tileSize, outputHeight - originY)
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    /// 单块 RGBA 缓冲字节数。
    public func tileBufferBytes(for rect: CGRect) -> Int {
        Int(rect.width) * Int(rect.height) * 4
    }
}
