import Foundation

/// 时间线视图维度：日 / 月 / 年 / 地图 / 全部。
public enum TimelineScale: String, CaseIterable, Identifiable, Sendable {
    case day
    case month
    case year
    case map
    case all

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .day: "日"
        case .month: "月"
        case .year: "年"
        case .map: "地图"
        case .all: "全部"
        }
    }

    /// 列表网格列数（虚拟列表 cell 布局）。
    public var gridColumnCount: Int {
        switch self {
        case .day: 2
        case .month: 3
        case .year: 4
        case .map: 3
        case .all: 3
        }
    }
}
