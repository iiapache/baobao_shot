import BabyCameraMilestone
import Foundation

public struct MilestoneFallbackResult: Sendable, Equatable {
    public var removedLocalNotificationIdentifiers: [String]
    public var babyId: String?
    public var milestoneId: String?

    public init(
        removedLocalNotificationIdentifiers: [String] = [],
        babyId: String? = nil,
        milestoneId: String? = nil
    ) {
        self.removedLocalNotificationIdentifiers = removedLocalNotificationIdentifiers
        self.babyId = babyId
        self.milestoneId = milestoneId
    }
}

/// 远程里程碑推送兜底：取消对应本地通知，避免与后端补发重复（design-ios §10.2）。
public struct MilestoneFallbackCoordinator: Sendable {
    private let scheduler: any LocalNotificationScheduling

    public init(scheduler: any LocalNotificationScheduling = LiveLocalNotificationScheduler()) {
        self.scheduler = scheduler
    }

    public func handleRemoteFallback(userInfo: [AnyHashable: Any]) async -> MilestoneFallbackResult {
        guard let payload = RemotePushPayload.from(userInfo: userInfo),
              payload.category == .milestone else {
            return MilestoneFallbackResult()
        }

        let babyId = payload.babyId ?? MilestoneNotificationPayload.from(userInfo: userInfo)?.babyId
        let milestoneId = payload.milestoneId ?? MilestoneNotificationPayload.from(userInfo: userInfo)?.milestoneId

        guard let babyId, let milestoneId else {
            return MilestoneFallbackResult(babyId: babyId, milestoneId: milestoneId)
        }

        let identifiers = await matchingLocalIdentifiers(babyId: babyId, milestoneId: milestoneId)
        if !identifiers.isEmpty {
            await scheduler.removePendingNotificationRequests(withIdentifiers: identifiers)
        }

        return MilestoneFallbackResult(
            removedLocalNotificationIdentifiers: identifiers,
            babyId: babyId,
            milestoneId: milestoneId
        )
    }

    private func matchingLocalIdentifiers(babyId: String, milestoneId: String) async -> [String] {
        let prefix = MilestoneNotificationIdentifier.babyPrefix(babyId: babyId)
        let milestonePrefix = "\(prefix)\(milestoneId)"
        let pending = await scheduler.pendingNotificationRequests()
        return pending
            .map(\.identifier)
            .filter { $0.hasPrefix(milestonePrefix) }
    }
}
