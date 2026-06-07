import Foundation

/// design-ios §15 埋点事件名常量目录（T7.9）。
/// 与 `docs/qa/analytics-events-catalog.md` 保持同步。
public enum AnalyticsEventCatalog {
    // MARK: - 启动 / 生命周期

    public enum Launch {
        public static let appLaunch = "app_launch"
        public static let appActive = "app_active"
        public static let appBackground = "app_background"
        public static let appFirstOpen = "app_first_open"
        public static let appCrash = "app_crash"
        public static let appKill = "app_kill"
    }

    // MARK: - 账号

    public enum Account {
        public static let loginAttempt = "login_attempt"
        public static let loginSuccess = "login_success"
        public static let loginFailure = "login_failure"
        public static let accountDelete = "account_delete"
        public static let consentChildData = "consent_child_data"
    }

    // MARK: - 家庭

    public enum Family {
        public static let create = "family_create"
        public static let inviteGenerate = "family_invite_generate"
        public static let join = "family_join"
        public static let transfer = "family_transfer"
        public static let takeoverVote = "family_takeover_vote"
        public static let memberRemove = "family_member_remove"
    }

    // MARK: - 宝宝

    public enum Baby {
        public static let create = "baby_create"
        public static let update = "baby_update"
        public static let switchBaby = "baby_switch"
    }

    // MARK: - 相机

    public enum Camera {
        public static let open = "camera_open"
        public static let capture = "camera_capture"
        public static let burst = "camera_burst"
        public static let filterApply = "camera_filter_apply"
        public static let livePhoto = "camera_live_photo"
        public static let importPhotos = "camera_import"
        public static let permissionDenied = "camera_permission_denied"
    }

    // MARK: - 编辑

    public enum Editor {
        public static let open = "editor_open"
        public static let applyFilter = "editor_apply_filter"
        public static let applySticker = "editor_apply_sticker"
        public static let applyText = "editor_apply_text"
        public static let saveDerived = "editor_save_derived"
        public static let reopen = "editor_reopen"
    }

    // MARK: - AI

    public enum AI {
        public static let playView = "ai_play_view"
        public static let submit = "ai_submit"
        public static let creditPreview = "ai_credit_preview"
        public static let running = "ai_running"
        public static let success = "ai_success"
        public static let failure = "ai_failure"
        public static let reject = "ai_reject"
        public static let refund = "ai_refund"
    }

    // MARK: - 时间线

    public enum Timeline {
        public static let viewDay = "timeline_view_day"
        public static let viewMonth = "timeline_view_month"
        public static let viewYear = "timeline_view_year"
        public static let viewMap = "timeline_view_map"
    }

    // MARK: - 里程碑

    public enum Milestone {
        public static let pushReceived = "milestone_push_received"
        public static let templateOpen = "milestone_template_open"
        public static let customCreate = "milestone_custom_create"
    }

    // MARK: - 家庭圈

    public enum Feed {
        public static let composeOpen = "post_compose_open"
        public static let publish = "post_publish"
        public static let like = "post_like"
        public static let comment = "post_comment"
        public static let delete = "post_delete"
        public static let open = "feed_open"
    }

    // MARK: - 分享

    public enum Share {
        public static let open = "share_open"
        public static let captionGenerate = "share_caption_generate"
        public static let toWechat = "share_to_wechat"
        public static let toSystem = "share_to_system"
    }

    // MARK: - 积分 / 订阅 / 广告

    public enum Monetization {
        public static let creditBalanceView = "credit_balance_view"
        public static let creditSignin = "credit_signin"
        public static let creditIAPStart = "credit_iap_start"
        public static let creditIAPSuccess = "credit_iap_success"
        public static let subscriptionPurchase = "subscription_purchase"
        public static let adImpression = "ad_impression"
        public static let adRewardGrant = "ad_reward_grant"
    }

    // MARK: - 备份

    public enum Backup {
        public static let authorize = "backup_authorize"
        public static let run = "backup_run"
        public static let failure = "backup_failure"
        public static let revoke = "backup_revoke"
    }

    // MARK: - 通知

    public enum Notification {
        public static let pushTokenRegister = "push_token_register"
        public static let pushNotificationOpen = "push_notification_open"
    }

    // MARK: - 性能 / 缓存（扩展）

    public enum Performance {
        public static let thumbnailCacheHit = "thumbnail_cache_hit"
        public static let thumbnailCacheMiss = "thumbnail_cache_miss"
    }

    // MARK: - 校验

    /// 全部事件名（用于 T7.9 脚本 / 单测对照 catalog）。
    public static let allEventNames: [String] = [
        Launch.appLaunch,
        Launch.appActive,
        Launch.appBackground,
        Launch.appFirstOpen,
        Launch.appCrash,
        Launch.appKill,
        Account.loginAttempt,
        Account.loginSuccess,
        Account.loginFailure,
        Account.accountDelete,
        Account.consentChildData,
        Family.create,
        Family.inviteGenerate,
        Family.join,
        Family.transfer,
        Family.takeoverVote,
        Family.memberRemove,
        Baby.create,
        Baby.update,
        Baby.switchBaby,
        Camera.open,
        Camera.capture,
        Camera.burst,
        Camera.filterApply,
        Camera.livePhoto,
        Camera.importPhotos,
        Camera.permissionDenied,
        Editor.open,
        Editor.applyFilter,
        Editor.applySticker,
        Editor.applyText,
        Editor.saveDerived,
        Editor.reopen,
        AI.playView,
        AI.submit,
        AI.creditPreview,
        AI.running,
        AI.success,
        AI.failure,
        AI.reject,
        AI.refund,
        Timeline.viewDay,
        Timeline.viewMonth,
        Timeline.viewYear,
        Timeline.viewMap,
        Milestone.pushReceived,
        Milestone.templateOpen,
        Milestone.customCreate,
        Feed.composeOpen,
        Feed.publish,
        Feed.like,
        Feed.comment,
        Feed.delete,
        Feed.open,
        Share.open,
        Share.captionGenerate,
        Share.toWechat,
        Share.toSystem,
        Monetization.creditBalanceView,
        Monetization.creditSignin,
        Monetization.creditIAPStart,
        Monetization.creditIAPSuccess,
        Monetization.subscriptionPurchase,
        Monetization.adImpression,
        Monetization.adRewardGrant,
        Backup.authorize,
        Backup.run,
        Backup.failure,
        Backup.revoke,
        Notification.pushTokenRegister,
        Notification.pushNotificationOpen,
        Performance.thumbnailCacheHit,
        Performance.thumbnailCacheMiss,
    ]

    public static var eventCount: Int { allEventNames.count }

    public static func contains(_ eventName: String) -> Bool {
        allEventNames.contains(eventName)
    }
}
