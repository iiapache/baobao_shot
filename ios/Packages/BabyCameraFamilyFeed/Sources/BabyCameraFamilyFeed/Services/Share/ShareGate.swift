import BabyCameraWatermark
import CoreGraphics
import Foundation

public enum ShareGateError: Error, Equatable, Sendable {
    case sourceMissing
    case unsupportedImageExtension(String)
}

/// 分享前门禁：校验源文件、深度合成策略与角标布局合规（T5.15）。
public struct ShareGate: Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func validate(_ request: SharePreparationRequest) throws {
        guard fileManager.fileExists(atPath: request.sourceURL.path) else {
            throw ShareGateError.sourceMissing
        }

        switch request.mediaKind {
        case .image:
            try validateImageExtension(request.sourceURL)
        case .video:
            break
        }
    }

    public func watermarkOptions(for request: SharePreparationRequest) -> WatermarkRenderOptions {
        request.requiresDeepSynthesisBadge ? .aiResult : .cameraCapture
    }

    /// 深度合成角标布局是否满足合规（配置比例 5%–8%、右下角锚点、实际落位正确）。
    public func isBadgeLayoutCompliant(canvasSize: CGSize) -> Bool {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return false
        }

        let layoutRatioCompliant =
            DeepSynthesisBadgeLayout.widthRatio >= 0.05
            && DeepSynthesisBadgeLayout.widthRatio <= 0.08
            && DeepSynthesisBadgeLayout.anchor == .bottomRight

        let rect = DeepSynthesisBadgeLayout.backgroundRect(canvasSize: canvasSize)
        let margin = DeepSynthesisBadgeLayout.margin(for: canvasSize)

        let anchoredBottomRight =
            abs(rect.maxX - (canvasSize.width - margin)) < 1
            && abs(rect.maxY - (canvasSize.height - margin)) < 1

        return layoutRatioCompliant && anchoredBottomRight
    }

    private func validateImageExtension(_ url: URL) throws {
        let ext = url.pathExtension.lowercased()
        let supported = ["heic", "jpg", "jpeg"]
        guard supported.contains(ext) else {
            throw ShareGateError.unsupportedImageExtension(ext)
        }
    }
}
