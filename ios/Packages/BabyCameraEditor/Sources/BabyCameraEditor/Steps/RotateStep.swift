import CoreImage
import Foundation

/// 旋转步骤（角度，顺时针为正）。
public struct RotateStep: EditStep {
    public var kind: EditStepKind { .rotate }

    public var degrees: Double

    public init(degrees: Double) {
        self.degrees = degrees
    }

    public func apply(to image: CIImage) -> CIImage {
        guard degrees != 0 else { return image }

        let radians = degrees * .pi / 180
        let transform = CGAffineTransform(rotationAngle: radians)
        return image.transformed(by: transform)
    }
}
