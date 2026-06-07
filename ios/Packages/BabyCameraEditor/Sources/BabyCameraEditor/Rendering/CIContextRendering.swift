import CoreImage
import CoreGraphics
import Foundation

/// CIContext 渲染抽象，便于单测注入 mock。
public protocol CIContextRendering: Sendable {
    func createCGImage(
        _ image: CIImage,
        from rect: CGRect,
        format: CIFormat,
        colorSpace: CGColorSpace
    ) -> CGImage?

    func render(
        _ image: CIImage,
        toBitmap data: UnsafeMutableRawPointer,
        rowBytes: Int,
        bounds: CGRect,
        format: CIFormat,
        colorSpace: CGColorSpace
    )
}

extension CIContext: CIContextRendering {}
