import Foundation

/// PRD §4.4：滤镜分类（日常 / 人像 / 胶片 / 卡通）。
public enum FilterCategory: String, Codable, CaseIterable, Sendable {
    case daily
    case portrait
    case film
    case cartoon

    public var displayName: String {
        switch self {
        case .daily: "日常"
        case .portrait: "人像"
        case .film: "胶片"
        case .cartoon: "卡通"
        }
    }
}
