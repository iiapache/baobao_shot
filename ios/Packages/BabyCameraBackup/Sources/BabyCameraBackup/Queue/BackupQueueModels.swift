import Foundation

public struct BackupQueueConfiguration: Sendable, Equatable {
    /// 单任务最大尝试次数（含首次执行）。
    public let maxAttemptsPerTask: Int
    /// 指数退避基础间隔（秒）：1s, 2s, 4s …
    public let retryBaseDelaySeconds: TimeInterval
    /// 单次退避上限（秒）。
    public let retryMaxDelaySeconds: TimeInterval
    /// 连续失败多少次后弹窗提示。
    public let consecutiveFailureAlertThreshold: Int
    /// 自动触发条件未满足时的重新调度间隔（秒）。
    public let triggerDeferDelaySeconds: TimeInterval

    public init(
        maxAttemptsPerTask: Int = 3,
        retryBaseDelaySeconds: TimeInterval = 1,
        retryMaxDelaySeconds: TimeInterval = 8,
        consecutiveFailureAlertThreshold: Int = 3,
        triggerDeferDelaySeconds: TimeInterval = 60
    ) {
        self.maxAttemptsPerTask = maxAttemptsPerTask
        self.retryBaseDelaySeconds = retryBaseDelaySeconds
        self.retryMaxDelaySeconds = retryMaxDelaySeconds
        self.consecutiveFailureAlertThreshold = consecutiveFailureAlertThreshold
        self.triggerDeferDelaySeconds = triggerDeferDelaySeconds
    }

    public static let `default` = BackupQueueConfiguration()
}

public struct BackupQueueTask: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let trigger: BackupRunTrigger
    public let providerKinds: [BackupKind]
    public let preferences: BackupAutoBackupPreferences
    public let enqueuedAt: Int64
    public var attemptCount: Int
    public var nextRetryAt: Int64?

    public init(
        id: UUID = UUID(),
        trigger: BackupRunTrigger,
        providerKinds: [BackupKind],
        preferences: BackupAutoBackupPreferences,
        enqueuedAt: Int64,
        attemptCount: Int = 0,
        nextRetryAt: Int64? = nil
    ) {
        self.id = id
        self.trigger = trigger
        self.providerKinds = providerKinds
        self.preferences = preferences
        self.enqueuedAt = enqueuedAt
        self.attemptCount = attemptCount
        self.nextRetryAt = nextRetryAt
    }
}

public struct BackupQueuePersistedState: Codable, Sendable, Equatable {
    public var tasks: [BackupQueueTask]
    public var consecutiveFailureCount: Int

    public init(tasks: [BackupQueueTask] = [], consecutiveFailureCount: Int = 0) {
        self.tasks = tasks
        self.consecutiveFailureCount = consecutiveFailureCount
    }
}

public enum BackupQueueError: Error, Sendable, Equatable {
    case noProvidersAvailable([BackupKind])
}

public protocol BackupQueuePersisting: Sendable {
    func loadState() async throws -> BackupQueuePersistedState
    func saveState(_ state: BackupQueuePersistedState) async throws
}

public protocol BackupProviderResolving: Sendable {
    func providers(for kinds: [BackupKind]) -> [any BackupProvider]
}

public struct BackupNetworkSnapshot: Sendable, Equatable {
    public let isOnline: Bool
    public let isOnWiFi: Bool

    public init(isOnline: Bool, isOnWiFi: Bool) {
        self.isOnline = isOnline
        self.isOnWiFi = isOnWiFi
    }
}

public protocol BackupNetworkMonitoring: Sendable {
    func start(onChange: @escaping @Sendable (BackupNetworkSnapshot) -> Void)
    func stop()
    func currentSnapshot() async -> BackupNetworkSnapshot
}

public protocol BackupConsecutiveFailureAlerting: Sendable {
    func showConsecutiveFailureAlert(consecutiveFailures: Int) async
}

public protocol BackupQueueSleeping: Sendable {
    func sleep(seconds: TimeInterval) async
}

public struct ImmediateBackupQueueSleeper: BackupQueueSleeping {
    public init() {}

    public func sleep(seconds: TimeInterval) async {
        let nanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}
