import BabyCameraNetwork
import Foundation

/// 推送类目定义，对齐 PRD §4.12 与 design-ios §10.1。
public struct NotificationCategory: Identifiable, Sendable, Equatable {
    public let code: NotificationCategoryCode
    public var enabled: Bool

    public var id: String { code.rawValue }

    public init(code: NotificationCategoryCode, enabled: Bool) {
        self.code = code
        self.enabled = enabled
    }

    /// PRD §4.12 默认开关。
    public static func defaultEnabled(for code: NotificationCategoryCode) -> Bool {
        switch code {
        case .milestone, .familyActivity, .aiDone, .credit:
            return true
        case .system:
            return false
        }
    }

    /// PRD §4.12：AI 任务完成 / 年度回顾不可关闭。
    public static func userCanDisable(_ code: NotificationCategoryCode) -> Bool {
        code != .aiDone
    }

    public var displayName: String {
        switch code {
        case .milestone:
            return "里程碑提醒"
        case .familyActivity:
            return "家人动态"
        case .aiDone:
            return "AI 任务完成"
        case .credit:
            return "积分到账 / 退还"
        case .system:
            return "系统活动 / 营销"
        }
    }

    public var subtitle: String {
        switch code {
        case .milestone:
            return "宝宝成长节点提醒"
        case .familyActivity:
            return "点赞、评论、新发布"
        case .aiDone:
            return "含年度回顾生成完成，不可关闭"
        case .credit:
            return "签到、充值、退还通知"
        case .system:
            return "活动与营销推送"
        }
    }

    public var systemImage: String {
        switch code {
        case .milestone:
            return "flag.fill"
        case .familyActivity:
            return "heart.fill"
        case .aiDone:
            return "sparkles"
        case .credit:
            return "creditcard.fill"
        case .system:
            return "megaphone.fill"
        }
    }

    public static var allDefaults: [NotificationCategory] {
        NotificationCategoryCode.allCases.map {
            NotificationCategory(code: $0, enabled: defaultEnabled(for: $0))
        }
    }

    public static func merge(
        remote: [NotificationSubscriptionItem],
        defaults: [NotificationCategory] = allDefaults
    ) -> [NotificationCategory] {
        let remoteMap = Dictionary(uniqueKeysWithValues: remote.map { ($0.category, $0.enabled) })
        return defaults.map { item in
            var merged = item
            if let enabled = remoteMap[item.code] {
                merged.enabled = enabled
            }
            if !userCanDisable(item.code) {
                merged.enabled = true
            }
            return merged
        }
    }
}
