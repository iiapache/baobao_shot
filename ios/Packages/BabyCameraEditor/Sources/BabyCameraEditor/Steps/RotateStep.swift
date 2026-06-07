import CoreImage
import Foundation

/// 旋转步骤（角度顺时针为正；PRD §4.4 含 90° 旋转与镜像）。
public struct RotateStep: EditStep {
    public var kind: EditStepKind { .rotate }

    public var degrees: Double
    public var mirrorHorizontal: Bool
    public var mirrorVertical: Bool

    public init(
        degrees: Double,
        mirrorHorizontal: Bool = false,
        mirrorVertical: Bool = false
    ) {
        self.degrees = degrees
        self.mirrorHorizontal = mirrorHorizontal
        self.mirrorVertical = mirrorVertical
    }

    public var isIdentity: Bool {
        degrees.truncatingRemainder(dividingBy: 360) == 0 && !mirrorHorizontal && !mirrorVertical
    }

    public func apply(to image: CIImage) -> CIImage {
        guard !isIdentity else { return image }

        let extent = image.extent
        let centerX = extent.midX
        let centerY = extent.midY

        var transform = CGAffineTransform(translationX: centerX, y: centerY)

        if mirrorHorizontal || mirrorVertical {
            transform = transform.scaledBy(
                x: mirrorHorizontal ? -1 : 1,
                y: mirrorVertical ? -1 : 1
            )
        }

        if degrees != 0 {
            let radians = degrees * .pi / 180
            transform = transform.rotated(by: radians)
        }

        transform = transform.translatedBy(x: -centerX, y: -centerY)
        return image.transformed(by: transform)
    }

    /// 顺时针旋转 90°。
    public static func rotate90Clockwise(from step: RotateStep = RotateStep(degrees: 0)) -> RotateStep {
        RotateStep(
            degrees: step.degrees + 90,
            mirrorHorizontal: step.mirrorHorizontal,
            mirrorVertical: step.mirrorVertical
        )
    }

    /// 水平镜像切换。
    public static func togglingMirrorHorizontal(from step: RotateStep) -> RotateStep {
        RotateStep(
            degrees: step.degrees,
            mirrorHorizontal: !step.mirrorHorizontal,
            mirrorVertical: step.mirrorVertical
        )
    }

    /// 垂直镜像切换。
    public static func togglingMirrorVertical(from step: RotateStep) -> RotateStep {
        RotateStep(
            degrees: step.degrees,
            mirrorHorizontal: step.mirrorHorizontal,
            mirrorVertical: !step.mirrorVertical
        )
    }
}
