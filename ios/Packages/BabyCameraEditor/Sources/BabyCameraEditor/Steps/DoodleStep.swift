import CoreImage
import Foundation

/// 涂鸦笔画点（归一化坐标）。
public struct DoodlePoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// 涂鸦步骤。
public struct DoodleStep: EditStep {
    public var kind: EditStepKind { .doodle }

    public var strokeColorHex: String
    public var strokeWidth: Double
    public var points: [DoodlePoint]

    public init(strokeColorHex: String = "#FF0000", strokeWidth: Double = 4, points: [DoodlePoint] = []) {
        self.strokeColorHex = strokeColorHex
        self.strokeWidth = strokeWidth
        self.points = points
    }

    public func apply(to image: CIImage) -> CIImage {
        guard points.count >= 2 else { return image }

        // 内核占位：用线段端点间的小圆点近似涂鸦，T2.13 替换为矢量渲染。
        var output = image
        let extent = image.extent

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let center = CGPoint(
                x: extent.minX + extent.width * current.x,
                y: extent.minY + extent.height * current.y
            )
            let radius = strokeWidth / 2
            let dotRect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )

            guard let dot = CIFilter(
                name: "CIConstantColorGenerator",
                parameters: [kCIInputColorKey: CIColor(red: 1, green: 0, blue: 0, alpha: 1)]
            )?.outputImage?.cropped(to: dotRect) else {
                continue
            }

            _ = previous
            output = dot.composited(over: output)
        }

        return output
    }
}
