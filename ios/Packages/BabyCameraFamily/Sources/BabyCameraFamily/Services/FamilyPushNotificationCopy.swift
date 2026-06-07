import BabyCameraDiagnostics
import Foundation

/// 家庭转让 / 接管相关推送文案占位 — 待 notification-svc 接入后复用
public enum FamilyPushNotificationCopy {
    // MARK: - 转让

    public static let transferToNewAdminTitle = "你已成为家庭管理员"
    public static func transferToNewAdminBody(previousAdminName: String) -> String {
        "\(previousAdminName) 已将管理员权限转让给你"
    }

    public static let transferToMembersTitle = "家庭管理员已变更"
    public static func transferToMembersBody(newAdminName: String) -> String {
        "\(newAdminName) 现在是家庭管理员"
    }

    // MARK: - 接管

    public static let takeoverVoteStartedTitle = "管理员接管投票已开始"
    public static func takeoverVoteStartedBody(familyName: String) -> String {
        "「\(familyName)」有家人发起管理员接管投票，请及时参与"
    }

    public static let takeoverObjectionPeriodTitle = "管理员接管进入异议期"
    public static func takeoverObjectionPeriodBody(days: Int) -> String {
        "投票已通过，原管理员可在 \(days) 天内提出异议"
    }

    public static let takeoverCompletedTitle = "家庭管理员已变更"
    public static func takeoverCompletedBody(newAdminName: String) -> String {
        "\(newAdminName) 已通过投票成为家庭管理员"
    }

    public static let takeoverCancelledTitle = "管理员接管已取消"
    public static let takeoverCancelledBody = "原管理员已撤销本次接管流程"

    // MARK: - 埋点（design-ios §15，常量见 AnalyticsEventCatalog.Family）

    @available(*, deprecated, message: "Use AnalyticsFeatureTracks or AnalyticsEventCatalog.Family")
    public enum AnalyticsEvent {
        public static let transfer = AnalyticsEventCatalog.Family.transfer
        public static let takeoverVote = AnalyticsEventCatalog.Family.takeoverVote
        public static let memberRemove = AnalyticsEventCatalog.Family.memberRemove
    }

    public static func track(_ event: String, parameters: [String: String] = [:]) {
        AnalyticsService.track(event, parameters: parameters)
    }
}
