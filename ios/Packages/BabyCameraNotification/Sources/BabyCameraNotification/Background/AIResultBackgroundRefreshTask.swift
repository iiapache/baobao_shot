import BabyCameraNetwork
import Foundation

public enum AIResultBackgroundRefreshTask {
    public static let identifier = "com.babycamera.background.ai-result-download"
}

public protocol PendingAIRefreshStoring: Sendable {
    func enqueue(_ payload: RemotePushPayload) async
    func dequeueAll() async -> [RemotePushPayload]
}

public actor InMemoryPendingAIRefreshStore: PendingAIRefreshStoring {
    private var payloads: [RemotePushPayload] = []

    public init() {}

    public func enqueue(_ payload: RemotePushPayload) async {
        payloads.append(payload)
    }

    public func dequeueAll() async -> [RemotePushPayload] {
        let current = payloads
        payloads.removeAll()
        return current
    }
}

public final class UserDefaultsPendingAIRefreshStore: PendingAIRefreshStoring, @unchecked Sendable {
    public static let storageKey = "com.babycamera.notification.pendingAIRefresh"

    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, key: String = storageKey) {
        self.defaults = defaults
        self.key = key
    }

    public func enqueue(_ payload: RemotePushPayload) async {
        lock.lock()
        defer { lock.unlock() }
        var current = loadLocked()
        current.append(payload)
        saveLocked(current)
    }

    public func dequeueAll() async -> [RemotePushPayload] {
        lock.lock()
        defer { lock.unlock() }
        let current = loadLocked()
        saveLocked([])
        return current
    }

    private func loadLocked() -> [RemotePushPayload] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([StoredPayload].self, from: data) else {
            return []
        }
        return decoded.map(\.payload)
    }

    private func saveLocked(_ payloads: [RemotePushPayload]) {
        let stored = payloads.map(StoredPayload.init)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: key)
    }

    private struct StoredPayload: Codable {
        let category: String
        let isSilent: Bool
        let taskId: String?
        let state: String?
        let resultUrl: String?
        let thumbnailUrl: String?
        let babyId: String?
        let milestoneId: String?
        let templateId: String?

        init(_ payload: RemotePushPayload) {
            category = payload.category.rawValue
            isSilent = payload.isSilent
            taskId = payload.taskId
            state = payload.state
            resultUrl = payload.resultUrl
            thumbnailUrl = payload.thumbnailUrl
            babyId = payload.babyId
            milestoneId = payload.milestoneId
            templateId = payload.templateId
        }

        var payload: RemotePushPayload {
            RemotePushPayload(
                category: NotificationCategoryCode(rawValue: category) ?? .aiDone,
                isSilent: isSilent,
                taskId: taskId,
                state: state,
                resultUrl: resultUrl,
                thumbnailUrl: thumbnailUrl,
                babyId: babyId,
                milestoneId: milestoneId,
                templateId: templateId
            )
        }
    }
}

public protocol AIResultBackgroundRefreshExecuting: Sendable {
    func execute(_ payloads: [RemotePushPayload]) async -> Bool
}

public struct ClosureAIResultBackgroundExecutor: AIResultBackgroundRefreshExecuting, Sendable {
    private let handler: @Sendable ([RemotePushPayload]) async -> Bool

    public init(handler: @escaping @Sendable ([RemotePushPayload]) async -> Bool) {
        self.handler = handler
    }

    public func execute(_ payloads: [RemotePushPayload]) async -> Bool {
        await handler(payloads)
    }
}

public enum AIResultBackgroundRefreshRegistrar {
    public static func register(
        scheduler: any BackgroundRefreshScheduling,
        pendingStore: any PendingAIRefreshStoring,
        executor: any AIResultBackgroundRefreshExecuting
    ) {
        scheduler.register(identifier: AIResultBackgroundRefreshTask.identifier) {
            let payloads = await pendingStore.dequeueAll()
            guard !payloads.isEmpty else { return true }
            return await executor.execute(payloads)
        }
    }
}
