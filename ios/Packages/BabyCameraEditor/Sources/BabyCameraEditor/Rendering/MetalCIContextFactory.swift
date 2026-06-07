import CoreImage
import Foundation
import Metal

enum MetalCIContextFactory {
    static func makeContext(name: String = "BabyCamera.EditorRenderer") throws -> CIContext {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw EditorRenderError.metalUnavailable
        }

        var options: [CIContextOption: Any] = [
            .workingColorSpace: CGColorSpaceCreateDeviceRGB() as Any,
            .cacheIntermediates: false,
        ]
        if #available(iOS 17.0, *) {
            options[.name] = name
        }
        return CIContext(mtlDevice: device, options: options)
    }
}
