import CoreImage
import CoreVideo
import Foundation
import Metal

/// 相机实时滤镜管线：CIContext + Metal 纹理缓存（design-ios §7.1–§7.2）。
public final class RealtimeFilterPipeline: @unchecked Sendable {
    public private(set) var configuration: RealtimeFilterPipelineConfiguration

    private let metalDevice: MTLDevice
    private let ciContext: CIContext
    private var textureCache: CVMetalTextureCache?
    private var lastProcessedTimestamp: CFAbsoluteTime = 0

    public init(
        configuration: RealtimeFilterPipelineConfiguration = .default,
        metalDevice: MTLDevice? = MTLCreateSystemDefaultDevice()
    ) {
        guard let metalDevice else {
            fatalError("RealtimeFilterPipeline requires a Metal-capable device")
        }
        self.configuration = configuration
        self.metalDevice = metalDevice

        var options: [CIContextOption: Any] = [
            .workingColorSpace: CGColorSpaceCreateDeviceRGB() as Any,
            .cacheIntermediates: configuration.cacheIntermediates,
        ]
        if #available(iOS 17.0, *) {
            options[.name] = "BabyCamera.RealtimeFilterPipeline"
        }
        self.ciContext = CIContext(mtlDevice: metalDevice, options: options)

        var cache: CVMetalTextureCache?
        let status = CVMetalTextureCacheCreate(nil, nil, metalDevice, nil, &cache)
        if status == kCVReturnSuccess {
            textureCache = cache
        }
    }

    // MARK: - Configuration

    public func updateConfiguration(_ configuration: RealtimeFilterPipelineConfiguration) {
        self.configuration = configuration
    }

    public func selectFilter(_ identifier: RealtimeFilterIdentifier) {
        var next = configuration
        next.selectFilter(identifier)
        configuration = next
    }

    // MARK: - Frame pacing

    /// 按 `targetFrameRate`（默认 30fps）节流，跳过多余帧以降低 GPU 负载。
    public func shouldProcessFrame(at timestamp: CFAbsoluteTime) -> Bool {
        let interval = configuration.frameInterval
        guard interval > 0 else { return true }
        guard timestamp - lastProcessedTimestamp >= interval else { return false }
        lastProcessedTimestamp = timestamp
        return true
    }

    public func resetFramePacing() {
        lastProcessedTimestamp = 0
    }

    // MARK: - Filter

    /// 对单帧 `CIImage` 应用当前滤镜。
    public func applyFilter(to image: CIImage) -> CIImage {
        let preset = RealtimeFilterCatalog.preset(for: configuration.activeFilter)
        guard let filterName = preset.ciFilterName else { return image }
        guard let filter = CIFilter(name: filterName) else { return image }

        filter.setValue(image, forKey: kCIInputImageKey)
        if let key = preset.intensityParameterKey {
            filter.setValue(configuration.filterIntensity, forKey: key)
        }
        return filter.outputImage ?? image
    }

    // MARK: - Metal rendering

    public var context: CIContext { ciContext }
    public var device: MTLDevice { metalDevice }

    /// 将 `CIImage` 渲染到 Metal 纹理（预览 MTKView 路径）。
    @discardableResult
    public func render(
        _ image: CIImage,
        to texture: MTLTexture,
        bounds: CGRect,
        colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    ) -> Bool {
        ciContext.render(
            image,
            to: texture,
            commandBuffer: nil,
            bounds: bounds,
            colorSpace: colorSpace
        )
        return true
    }

    /// 从 `CVPixelBuffer`（`AVCaptureVideoDataOutput`）创建 Metal 纹理，复用 `CVMetalTextureCache`。
    public func makeTexture(
        from pixelBuffer: CVPixelBuffer,
        pixelFormat: MTLPixelFormat = .bgra8Unorm,
        planeIndex: Int = 0
    ) -> MTLTexture? {
        guard let textureCache else { return nil }

        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil,
            textureCache,
            pixelBuffer,
            nil,
            pixelFormat,
            width,
            height,
            planeIndex,
            &cvTexture
        )
        guard status == kCVReturnSuccess, let cvTexture else { return nil }
        return CVMetalTextureGetTexture(cvTexture)
    }

    /// 完整预览帧处理：节流 → 滤镜 → 渲染。
    @discardableResult
    public func processPreviewFrame(
        _ image: CIImage,
        to texture: MTLTexture,
        bounds: CGRect,
        timestamp: CFAbsoluteTime
    ) -> Bool {
        guard shouldProcessFrame(at: timestamp) else { return false }
        let filtered = applyFilter(to: image)
        return render(filtered, to: texture, bounds: bounds)
    }
}
