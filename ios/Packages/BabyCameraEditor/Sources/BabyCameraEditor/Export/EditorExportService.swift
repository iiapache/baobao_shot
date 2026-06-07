import BabyCameraImageKit
import CoreGraphics
import CoreImage
import Foundation

/// 导出选项。
public struct EditorExportOptions: Sendable, Equatable {
    public var format: ImageFormat
    public var quality: CGFloat

    public init(format: ImageFormat, quality: CGFloat = ImageCodec.defaultJPEGQuality) {
        self.format = format
        self.quality = quality
    }
}

/// 导出结果。
public struct EditorExportResult: Sendable, Equatable {
    public let encoded: EncodedImage
    public let outputURL: URL?

    public init(encoded: EncodedImage, outputURL: URL? = nil) {
        self.encoded = encoded
        self.outputURL = outputURL
    }
}

/// 编辑器导出服务：离屏渲染 + HEIC/JPG 编码。
public struct EditorExportService: Sendable {
    private let renderer: EditorRendering
    private let codec: ImageCodecProtocol
    private let configuration: EditorRenderConfiguration

    public init(
        renderer: EditorRendering,
        codec: ImageCodecProtocol = ImageCodec(),
        configuration: EditorRenderConfiguration = .default
    ) {
        self.renderer = renderer
        self.codec = codec
        self.configuration = configuration
    }

    /// 便捷构造：内部创建 Metal `EditorRenderer`。
    public init(
        codec: ImageCodecProtocol = ImageCodec(),
        configuration: EditorRenderConfiguration = .default
    ) throws {
        let renderer = try EditorRenderer(configuration: configuration)
        self.init(renderer: renderer, codec: codec, configuration: configuration)
    }

    public var renderConfiguration: EditorRenderConfiguration { configuration }

    /// 渲染并编码为 HEIC/JPG Data。
    public func export(
        baseImage: CIImage,
        editorState: EditorState,
        options: EditorExportOptions
    ) throws -> EncodedImage {
        let cgImage = try renderer.renderToCGImage(baseImage: baseImage, editorState: editorState)
        return try codec.encode(image: cgImage, format: options.format, quality: options.quality)
    }

    /// 渲染、编码并写入目标 URL。
    @discardableResult
    public func exportToFile(
        baseImage: CIImage,
        editorState: EditorState,
        options: EditorExportOptions,
        outputURL: URL
    ) throws -> EditorExportResult {
        let encoded = try export(baseImage: baseImage, editorState: editorState, options: options)
        try encoded.data.write(to: outputURL, options: .atomic)
        return EditorExportResult(encoded: encoded, outputURL: outputURL)
    }

    /// 按格式解析默认扩展名。
    public static func fileExtension(for encoded: EncodedImage) -> String {
        encoded.format.fileExtension
    }
}
