import Foundation

/// 各 Feature 埋点 stub 入口（T7.9 最小补全 + 单测可遍历）。
public enum AnalyticsFeatureTracks {
    // MARK: - 启动 / 生命周期

    public static func trackAppLaunch(coldStart: Bool) {
        AnalyticsService.track(AnalyticsEventCatalog.Launch.appLaunch, parameters: ["coldStart": coldStart ? "1" : "0"])
    }

    public static func trackAppActive() {
        AnalyticsService.track(AnalyticsEventCatalog.Launch.appActive)
    }

    public static func trackAppBackground() {
        AnalyticsService.track(AnalyticsEventCatalog.Launch.appBackground)
    }

    public static func trackAppFirstOpen() {
        AnalyticsService.track(AnalyticsEventCatalog.Launch.appFirstOpen)
    }

    public static func trackAppCrash(crashId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Launch.appCrash, parameters: ["crashId": crashId])
    }

    public static func trackAppKill() {
        AnalyticsService.track(AnalyticsEventCatalog.Launch.appKill)
    }

    // MARK: - 账号

    public static func trackLoginAttempt(method: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Account.loginAttempt, parameters: ["method": method])
    }

    public static func trackLoginSuccess(method: String, isNewUser: Bool) {
        AnalyticsService.track(
            AnalyticsEventCatalog.Account.loginSuccess,
            parameters: ["method": method, "isNewUser": isNewUser ? "1" : "0"]
        )
    }

    public static func trackLoginFailure(method: String, errorCode: String) {
        AnalyticsService.track(
            AnalyticsEventCatalog.Account.loginFailure,
            parameters: ["method": method, "errorCode": errorCode]
        )
    }

    public static func trackAccountDelete() {
        AnalyticsService.track(AnalyticsEventCatalog.Account.accountDelete)
    }

    public static func trackConsentChildData(version: String, accepted: Bool) {
        AnalyticsService.track(
            AnalyticsEventCatalog.Account.consentChildData,
            parameters: ["version": version, "accepted": accepted ? "1" : "0"]
        )
    }

    // MARK: - 家庭

    public static func trackFamilyCreate(familyId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Family.create, parameters: ["familyId": familyId])
    }

    public static func trackFamilyInviteGenerate(familyId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Family.inviteGenerate, parameters: ["familyId": familyId])
    }

    public static func trackFamilyJoin(familyId: String, relation: String) {
        AnalyticsService.track(
            AnalyticsEventCatalog.Family.join,
            parameters: ["familyId": familyId, "relation": relation]
        )
    }

    public static func trackFamilyTransfer(familyId: String, newAdminUserId: String) {
        AnalyticsService.track(
            AnalyticsEventCatalog.Family.transfer,
            parameters: ["familyId": familyId, "newAdminUserId": newAdminUserId]
        )
    }

    public static func trackFamilyTakeoverVote(familyId: String, vote: String) {
        AnalyticsService.track(
            AnalyticsEventCatalog.Family.takeoverVote,
            parameters: ["familyId": familyId, "vote": vote]
        )
    }

    public static func trackFamilyMemberRemove(familyId: String, targetUserId: String) {
        AnalyticsService.track(
            AnalyticsEventCatalog.Family.memberRemove,
            parameters: ["familyId": familyId, "targetUserId": targetUserId]
        )
    }

    // MARK: - 宝宝

    public static func trackBabyCreate(babyId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Baby.create, parameters: ["babyId": babyId])
    }

    public static func trackBabyUpdate(babyId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Baby.update, parameters: ["babyId": babyId])
    }

    public static func trackBabySwitch(babyId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Baby.switchBaby, parameters: ["babyId": babyId])
    }

    // MARK: - 相机

    public static func trackCameraOpen() {
        AnalyticsService.track(AnalyticsEventCatalog.Camera.open)
    }

    public static func trackCameraCapture(mediaType: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Camera.capture, parameters: ["mediaType": mediaType])
    }

    public static func trackCameraBurst(count: Int) {
        AnalyticsService.track(AnalyticsEventCatalog.Camera.burst, parameters: ["count": String(count)])
    }

    public static func trackCameraFilterApply(filterId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Camera.filterApply, parameters: ["filterId": filterId])
    }

    public static func trackCameraLivePhoto(enabled: Bool) {
        AnalyticsService.track(AnalyticsEventCatalog.Camera.livePhoto, parameters: ["enabled": enabled ? "1" : "0"])
    }

    public static func trackCameraImport(count: Int) {
        AnalyticsService.track(AnalyticsEventCatalog.Camera.importPhotos, parameters: ["count": String(count)])
    }

    public static func trackCameraPermissionDenied() {
        AnalyticsService.track(AnalyticsEventCatalog.Camera.permissionDenied)
    }

    // MARK: - 编辑

    public static func trackEditorOpen(source: String, elapsedMs: Int) {
        AnalyticsService.track(
            AnalyticsEventCatalog.Editor.open,
            parameters: ["source": source, "elapsedMs": String(elapsedMs)]
        )
    }

    public static func trackEditorApplyFilter(filterId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Editor.applyFilter, parameters: ["filterId": filterId])
    }

    public static func trackEditorApplySticker(stickerId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Editor.applySticker, parameters: ["stickerId": stickerId])
    }

    public static func trackEditorApplyText() {
        AnalyticsService.track(AnalyticsEventCatalog.Editor.applyText)
    }

    public static func trackEditorSaveDerived(assetId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Editor.saveDerived, parameters: ["assetId": assetId])
    }

    public static func trackEditorReopen(assetId: String, revision: Int) {
        AnalyticsService.track(
            AnalyticsEventCatalog.Editor.reopen,
            parameters: ["assetId": assetId, "revision": String(revision)]
        )
    }

    // MARK: - AI

    public static func trackAIPlayView(playId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.AI.playView, parameters: ["playId": playId])
    }

    public static func trackAISubmit(playId: String, taskId: String) {
        AnalyticsService.track(
            AnalyticsEventCatalog.AI.submit,
            parameters: ["playId": playId, "taskId": taskId]
        )
    }

    public static func trackAICreditPreview(playId: String, credits: Int) {
        AnalyticsService.track(
            AnalyticsEventCatalog.AI.creditPreview,
            parameters: ["playId": playId, "credits": String(credits)]
        )
    }

    public static func trackAIRunning(taskId: String, progress: Int) {
        AnalyticsService.track(
            AnalyticsEventCatalog.AI.running,
            parameters: ["taskId": taskId, "progress": String(progress)]
        )
    }

    public static func trackAISuccess(taskId: String, durationMs: Int) {
        AnalyticsService.track(
            AnalyticsEventCatalog.AI.success,
            parameters: ["taskId": taskId, "durationMs": String(durationMs)]
        )
    }

    public static func trackAIFailure(taskId: String, errorCode: String) {
        AnalyticsService.track(
            AnalyticsEventCatalog.AI.failure,
            parameters: ["taskId": taskId, "errorCode": errorCode]
        )
    }

    public static func trackAIReject(taskId: String, reason: String) {
        AnalyticsService.track(
            AnalyticsEventCatalog.AI.reject,
            parameters: ["taskId": taskId, "reason": reason]
        )
    }

    public static func trackAIRefund(taskId: String, credits: Int) {
        AnalyticsService.track(
            AnalyticsEventCatalog.AI.refund,
            parameters: ["taskId": taskId, "credits": String(credits)]
        )
    }

    // MARK: - 时间线

    public static func trackTimelineViewDay(date: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Timeline.viewDay, parameters: ["date": date])
    }

    public static func trackTimelineViewMonth(month: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Timeline.viewMonth, parameters: ["month": month])
    }

    public static func trackTimelineViewYear(year: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Timeline.viewYear, parameters: ["year": year])
    }

    public static func trackTimelineViewMap() {
        AnalyticsService.track(AnalyticsEventCatalog.Timeline.viewMap)
    }

    // MARK: - 里程碑

    public static func trackMilestonePushReceived(milestoneId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Milestone.pushReceived, parameters: ["milestoneId": milestoneId])
    }

    public static func trackMilestoneTemplateOpen(milestoneId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Milestone.templateOpen, parameters: ["milestoneId": milestoneId])
    }

    public static func trackMilestoneCustomCreate(milestoneId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Milestone.customCreate, parameters: ["milestoneId": milestoneId])
    }

    // MARK: - 家庭圈

    public static func trackPostComposeOpen() {
        AnalyticsService.track(AnalyticsEventCatalog.Feed.composeOpen)
    }

    public static func trackPostPublish(postId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Feed.publish, parameters: ["postId": postId])
    }

    public static func trackPostLike(postId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Feed.like, parameters: ["postId": postId])
    }

    public static func trackPostComment(postId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Feed.comment, parameters: ["postId": postId])
    }

    public static func trackPostDelete(postId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Feed.delete, parameters: ["postId": postId])
    }

    public static func trackFeedOpen(familyId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Feed.open, parameters: ["familyId": familyId])
    }

    // MARK: - 分享

    public static func trackShareOpen(assetId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Share.open, parameters: ["assetId": assetId])
    }

    public static func trackShareCaptionGenerate(assetId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Share.captionGenerate, parameters: ["assetId": assetId])
    }

    public static func trackShareToWechat(channel: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Share.toWechat, parameters: ["channel": channel])
    }

    public static func trackShareToSystem() {
        AnalyticsService.track(AnalyticsEventCatalog.Share.toSystem)
    }

    // MARK: - 积分 / 订阅 / 广告

    public static func trackCreditBalanceView(balance: Int) {
        AnalyticsService.track(AnalyticsEventCatalog.Monetization.creditBalanceView, parameters: ["balance": String(balance)])
    }

    public static func trackCreditSignin(streak: Int) {
        AnalyticsService.track(AnalyticsEventCatalog.Monetization.creditSignin, parameters: ["streak": String(streak)])
    }

    public static func trackCreditIAPStart(productId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Monetization.creditIAPStart, parameters: ["productId": productId])
    }

    public static func trackCreditIAPSuccess(productId: String, credits: Int) {
        AnalyticsService.track(
            AnalyticsEventCatalog.Monetization.creditIAPSuccess,
            parameters: ["productId": productId, "credits": String(credits)]
        )
    }

    public static func trackSubscriptionPurchase(productId: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Monetization.subscriptionPurchase, parameters: ["productId": productId])
    }

    public static func trackAdImpression(placement: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Monetization.adImpression, parameters: ["placement": placement])
    }

    public static func trackAdRewardGrant(credits: Int) {
        AnalyticsService.track(AnalyticsEventCatalog.Monetization.adRewardGrant, parameters: ["credits": String(credits)])
    }

    // MARK: - 备份

    public static func trackBackupAuthorize(target: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Backup.authorize, parameters: ["target": target])
    }

    public static func trackBackupRun(target: String, bytes: Int) {
        AnalyticsService.track(
            AnalyticsEventCatalog.Backup.run,
            parameters: ["target": target, "bytes": String(bytes)]
        )
    }

    public static func trackBackupFailure(target: String, errorCode: String) {
        AnalyticsService.track(
            AnalyticsEventCatalog.Backup.failure,
            parameters: ["target": target, "errorCode": errorCode]
        )
    }

    public static func trackBackupRevoke(target: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Backup.revoke, parameters: ["target": target])
    }

    // MARK: - 通知

    public static func trackPushTokenRegister() {
        AnalyticsService.track(AnalyticsEventCatalog.Notification.pushTokenRegister)
    }

    public static func trackPushNotificationOpen(type: String, deepLink: String) {
        AnalyticsService.track(
            AnalyticsEventCatalog.Notification.pushNotificationOpen,
            parameters: ["type": type, "deepLink": deepLink]
        )
    }

    // MARK: - 性能 / 缓存

    public static func trackThumbnailCacheHit(key: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Performance.thumbnailCacheHit, parameters: ["key": key])
    }

    public static func trackThumbnailCacheMiss(key: String) {
        AnalyticsService.track(AnalyticsEventCatalog.Performance.thumbnailCacheMiss, parameters: ["key": key])
    }

    // MARK: - 单测 / 校验

    /// 遍历全部 catalog 事件，确保每个事件至少有一条 `AnalyticsService.track` 调用链。
    public static func emitAllStubTracksForVerification() {
        trackAppLaunch(coldStart: true)
        trackAppActive()
        trackAppBackground()
        trackAppFirstOpen()
        trackAppCrash(crashId: "verify")
        trackAppKill()
        trackLoginAttempt(method: "apple")
        trackLoginSuccess(method: "apple", isNewUser: false)
        trackLoginFailure(method: "phone", errorCode: "verify")
        trackAccountDelete()
        trackConsentChildData(version: "1", accepted: true)
        trackFamilyCreate(familyId: "f1")
        trackFamilyInviteGenerate(familyId: "f1")
        trackFamilyJoin(familyId: "f1", relation: "mom")
        trackFamilyTransfer(familyId: "f1", newAdminUserId: "u2")
        trackFamilyTakeoverVote(familyId: "f1", vote: "yes")
        trackFamilyMemberRemove(familyId: "f1", targetUserId: "u3")
        trackBabyCreate(babyId: "b1")
        trackBabyUpdate(babyId: "b1")
        trackBabySwitch(babyId: "b1")
        trackCameraOpen()
        trackCameraCapture(mediaType: "photo")
        trackCameraBurst(count: 3)
        trackCameraFilterApply(filterId: "warm")
        trackCameraLivePhoto(enabled: true)
        trackCameraImport(count: 1)
        trackCameraPermissionDenied()
        trackEditorOpen(source: "camera", elapsedMs: 100)
        trackEditorApplyFilter(filterId: "warm")
        trackEditorApplySticker(stickerId: "s1")
        trackEditorApplyText()
        trackEditorSaveDerived(assetId: "a1")
        trackEditorReopen(assetId: "a1", revision: 2)
        trackAIPlayView(playId: "p1")
        trackAISubmit(playId: "p1", taskId: "t1")
        trackAICreditPreview(playId: "p1", credits: 10)
        trackAIRunning(taskId: "t1", progress: 50)
        trackAISuccess(taskId: "t1", durationMs: 3000)
        trackAIFailure(taskId: "t1", errorCode: "timeout")
        trackAIReject(taskId: "t1", reason: "policy")
        trackAIRefund(taskId: "t1", credits: 10)
        trackTimelineViewDay(date: "2026-06-06")
        trackTimelineViewMonth(month: "2026-06")
        trackTimelineViewYear(year: "2026")
        trackTimelineViewMap()
        trackMilestonePushReceived(milestoneId: "m1")
        trackMilestoneTemplateOpen(milestoneId: "m1")
        trackMilestoneCustomCreate(milestoneId: "m1")
        trackPostComposeOpen()
        trackPostPublish(postId: "post1")
        trackPostLike(postId: "post1")
        trackPostComment(postId: "post1")
        trackPostDelete(postId: "post1")
        trackFeedOpen(familyId: "f1")
        trackShareOpen(assetId: "a1")
        trackShareCaptionGenerate(assetId: "a1")
        trackShareToWechat(channel: "session")
        trackShareToSystem()
        trackCreditBalanceView(balance: 100)
        trackCreditSignin(streak: 3)
        trackCreditIAPStart(productId: "credits_100")
        trackCreditIAPSuccess(productId: "credits_100", credits: 100)
        trackSubscriptionPurchase(productId: "sub_monthly")
        trackAdImpression(placement: "reward")
        trackAdRewardGrant(credits: 5)
        trackBackupAuthorize(target: "icloud")
        trackBackupRun(target: "icloud", bytes: 1024)
        trackBackupFailure(target: "icloud", errorCode: "network")
        trackBackupRevoke(target: "icloud")
        trackPushTokenRegister()
        trackPushNotificationOpen(type: "milestone", deepLink: "app://milestone/m1")
        trackThumbnailCacheHit(key: "k1")
        trackThumbnailCacheMiss(key: "k2")
    }
}
