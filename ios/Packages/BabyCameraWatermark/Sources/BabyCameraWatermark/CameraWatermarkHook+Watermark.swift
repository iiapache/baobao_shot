import BabyCameraCamera
import BabyCameraImageKit
import Foundation

public extension CameraWatermarkHooks {
    /// 使用 `WatermarkRenderer` 构建烧录 hook，供 `PhotoCapturePipeline` 在开启「烧入水印」时调用。
    static func make(
        renderer: WatermarkRenderer,
        isSubscribed: @escaping @Sendable () -> Bool = { false }
    ) -> CameraWatermarkHook {
        { request in
            let destination = Self.watermarkedDestinationURL(for: request)
            return try renderer.render(
                sourceFileURL: request.sourceFileURL,
                format: request.format,
                isSubscribed: isSubscribed(),
                destinationURL: destination
            )
        }
    }

    static func watermarkedDestinationURL(for request: CameraWatermarkRequest) -> URL {
        let baseName = request.sourceFileURL.deletingPathExtension().lastPathComponent
        let fileName = "\(baseName)_watermarked.\(request.format.fileExtension)"
        return request.sourceFileURL.deletingLastPathComponent().appendingPathComponent(fileName)
    }
}
