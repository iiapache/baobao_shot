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

        var output = image
        let extent = image.extent
        let color = ColorHex.ciColor(from: strokeColorHex)
        let radius = max(strokeWidth / 2, 0.5)

        for index in 1..<points.count {
            let start = points[index - 1]
            let end = points[index]
            let startPoint = CGPoint(
                x: extent.minX + extent.width * start.x,
                y: extent.minY + extent.height * start.y
            )
            let endPoint = CGPoint(
                x: extent.minX + extent.width * end.x,
                y: extent.minY + extent.height * end.y
            )

            let segment = strokeSegment(
                from: startPoint,
                to: endPoint,
                radius: radius,
                color: color
            )
            output = segment.composited(over: output)
        }

        return output
    }

    private func strokeSegment(from start: CGPoint, to end: CGPoint, radius: Double, color: CIColor) -> CIImage {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(hypot(dx, dy), radius * 2)
        let angle = atan2(dy, dx)
        let center = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let rect = CGRect(
            x: center.x - length / 2,
            y: center.y - radius,
            width: length,
            height: radius * 2
        )

        guard let capsule = CIFilter(
            name: "CIConstantColorGenerator",
            parameters: [kCIInputColorKey: color]
        )?.outputImage?.cropped(to: rect) else {
            return CIImage.empty()
        }

        return capsule.transformed(by: CGAffineTransform(rotationAngle: angle))
    }
}
