import Foundation

/// 相机实时预览滤镜标识（design-ios §7.2）。
public enum RealtimeFilterIdentifier: String, Codable, CaseIterable, Sendable, Hashable {
    case none
    case sepia
    case mono
    case vivid
    case fade
    case chrome
    case instant
    case noir

    /// 是否为「无滤镜」原图。
    public var isOriginal: Bool { self == .none }
}
