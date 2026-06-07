import Foundation

/// 第三方分享入口（T5.14）。小红书 / 抖音无官方代发 SDK，统一走系统分享面板。
public enum ShareDestination: String, Sendable, Equatable, CaseIterable {
    case system
    case xiaohongshu
    case douyin

    public var usesSystemShareSheet: Bool { true }

    public var displayName: String {
        switch self {
        case .system:
            return "系统分享"
        case .xiaohongshu:
            return "小红书"
        case .douyin:
            return "抖音"
        }
    }

    /// 剪贴板写入后的用户提示文案。
    public var clipboardHintMessage: String {
        switch self {
        case .system:
            return "智能文案已复制到剪贴板"
        case .xiaohongshu:
            return "智能文案已复制，分享至小红书后可直接粘贴"
        case .douyin:
            return "智能文案已复制，分享至抖音后可直接粘贴"
        }
    }
}
