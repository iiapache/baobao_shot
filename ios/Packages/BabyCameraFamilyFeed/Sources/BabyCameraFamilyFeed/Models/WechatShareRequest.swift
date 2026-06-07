import Foundation

/// 微信分享入参：经 `SharePreparer` 处理后的媒体 + 自动文案（T5.13）。
public struct WechatShareRequest: Sendable, Equatable {
    public let asset: SharePreparedAsset
    public let caption: String
    public let scene: WechatShareScene

    public init(
        asset: SharePreparedAsset,
        caption: String,
        scene: WechatShareScene
    ) {
        self.asset = asset
        self.caption = caption
        self.scene = scene
    }
}
