import CoreImage
import Foundation

/// 归一化裁剪矩形（0…1，原图像素空间）。
public struct NormalizedRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    func pixelRect(for imageExtent: CGRect) -> CGRect {
        CGRect(
            x: imageExtent.origin.x + imageExtent.width * x,
            y: imageExtent.origin.y + imageExtent.height * y,
            width: imageExtent.width * width,
            height: imageExtent.height * height
        )
    }
}

/// 裁剪步骤。
public struct CropStep: EditStep {
    public var kind: EditStepKind { .crop }

    public var rect: NormalizedRect
    public var aspectRatio: CropAspectRatio

    public init(rect: NormalizedRect, aspectRatio: CropAspectRatio = .free) {
        self.rect = rect
        self.aspectRatio = aspectRatio
    }

    public func apply(to image: CIImage) -> CIImage {
        let cropRect = rect.pixelRect(for: image.extent)
        return image.cropped(to: cropRect)
    }
}
