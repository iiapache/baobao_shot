import Foundation

/// 静默 AI 完成推送 → 持久化待下载任务并提交 BGAppRefreshTask（T5.18 / design-ios §10.1）。
public struct SilentPushBackgroundHandler: Sendable {
    private let refreshScheduler: any BackgroundRefreshScheduling
    private let pendingStore: any PendingAIRefreshStoring
    private let milestoneFallback: MilestoneFallbackCoordinator
    private let clock: any NotificationClock

    public init(
        refreshScheduler: any BackgroundRefreshScheduling,
        pendingStore: any PendingAIRefreshStoring = UserDefaultsPendingAIRefreshStore(),
        milestoneFallback: MilestoneFallbackCoordinator = MilestoneFallbackCoordinator(),
        clock: any NotificationClock = SystemNotificationClock()
    ) {
        self.refreshScheduler = refreshScheduler
        self.pendingStore = pendingStore
        self.milestoneFallback = milestoneFallback
        self.clock = clock
    }

    public enum HandlingOutcome: Sendable, Equatable {
        case ignored
        case milestoneFallback(MilestoneFallbackResult)
        case scheduledBackgroundRefresh(RemotePushPayload)
        case failedToSchedule(RemotePushPayload)
    }

    public func handle(userInfo: [AnyHashable: Any]) async -> HandlingOutcome {
        if RemotePushPayload.from(userInfo: userInfo)?.category == .milestone {
            let fallback = await milestoneFallback.handleRemoteFallback(userInfo: userInfo)
            if fallback.babyId != nil
                || fallback.milestoneId != nil
                || !fallback.removedLocalNotificationIdentifiers.isEmpty {
                return .milestoneFallback(fallback)
            }
            return .ignored
        }

        guard let payload = RemotePushPayload.from(userInfo: userInfo),
              payload.isSilentAIDone else {
            return .ignored
        }

        await pendingStore.enqueue(payload)
        let scheduled = await refreshScheduler.submit(
            BackgroundRefreshRequest(
                identifier: AIResultBackgroundRefreshTask.identifier,
                earliestBeginDate: clock.now()
            )
        )
        return scheduled ? .scheduledBackgroundRefresh(payload) : .failedToSchedule(payload)
    }
}

public protocol NotificationClock: Sendable {
    func now() -> Date
}

public struct SystemNotificationClock: NotificationClock, Sendable {
    public init() {}

    public func now() -> Date { Date() }
}
