import Foundation

/// 传给 OpenSDK 桥接层的分享载荷（T5.13 stub 可单测断言）。
public struct WechatSharePayload: Sendable, Equatable {
    public let scene: WechatShareScene
    public let title: String
    public let description: String
    public let mediaURL: URL
    public let mediaKind: ShareMediaKind
    public let thumbData: Data
    public let universalLink: String

    public init(
        scene: WechatShareScene,
        title: String,
        description: String,
        mediaURL: URL,
        mediaKind: ShareMediaKind,
        thumbData: Data,
        universalLink: String
    ) {
        self.scene = scene
        self.title = title
        self.description = description
        self.mediaURL = mediaURL
        self.mediaKind = mediaKind
        self.thumbData = thumbData
        self.universalLink = universalLink
    }
}
