import BabyCameraNetwork
import Foundation

/// 系统分享入参（T5.14）：媒体经 SharePreparer 水印处理后，配合智能文案走 `UIActivityViewController`。
public struct SystemShareRequest: Sendable, Equatable {
    public let preparationRequest: SharePreparationRequest
    /// 智能文案候选；为 `nil` 时使用 `fallbackCaption`。
    public let caption: CaptionCandidate?
    public let fallbackCaption: String
    public let destination: ShareDestination

    public init(
        preparationRequest: SharePreparationRequest,
        caption: CaptionCandidate? = nil,
        fallbackCaption: String,
        destination: ShareDestination
    ) {
        self.preparationRequest = preparationRequest
        self.caption = caption
        self.fallbackCaption = fallbackCaption
        self.destination = destination
    }
}
