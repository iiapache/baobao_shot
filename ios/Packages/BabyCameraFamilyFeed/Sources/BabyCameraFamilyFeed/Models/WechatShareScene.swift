import Foundation

/// 微信分享场景（T5.13）。
public enum WechatShareScene: String, Sendable, Equatable, CaseIterable {
    /// 微信朋友圈
    case timeline
    /// 微信好友
    case session
}
