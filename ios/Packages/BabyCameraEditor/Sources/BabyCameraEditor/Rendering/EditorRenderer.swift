import CoreGraphics
import CoreImage
import Foundation

/// 编辑器离屏渲染协议。
public protocol EditorRendering: Sendable {
    func render(baseImage: CIImage, steps: [AnyEditStep]) -> CIImage
    func renderToCGImage(baseImage: CIImage, editorState: EditorState) throws -> CGImage
}

/// Metal 离屏渲染：重放 EditStep 链并按需分块输出 CGImage。
public final class EditorRenderer: EditorRendering, @unchecked Sendable {
    private let context: CIContextRendering
    private let tileRenderer: TileRenderer
    private let configuration: EditorRenderConfiguration

    public init(
        context: CIContextRendering? = nil,
        configuration: EditorRenderConfiguration = .default
    ) throws {
        if let context {
            self.context = context
        } else {
            self.context = try MetalCIContextFactory.makeContext()
        }
        self.configuration = configuration
        self.tileRenderer = TileRenderer(context: self.context, configuration: configuration)
    }

    public func render(baseImage: CIImage, steps: [AnyEditStep]) -> CIImage {
        steps.reduce(baseImage) { current, step in
            step.apply(to: current)
        }
    }

    public func render(baseImage: CIImage, editorState: EditorState) -> CIImage {
        render(baseImage: baseImage, steps: editorState.steps)
    }

    public func renderToCGImage(baseImage: CIImage, editorState: EditorState) throws -> CGImage {
        let image = render(baseImage: baseImage, editorState: editorState)
        return try tileRenderer.renderToCGImage(image)
    }
}
