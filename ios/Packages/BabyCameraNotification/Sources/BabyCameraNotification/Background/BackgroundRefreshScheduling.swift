import Foundation

public struct BackgroundRefreshRequest: Sendable, Equatable {
    public let identifier: String
    public let earliestBeginDate: Date?

    public init(identifier: String, earliestBeginDate: Date? = nil) {
        self.identifier = identifier
        self.earliestBeginDate = earliestBeginDate
    }
}

public enum BackgroundRefreshHandlingResult: Sendable, Equatable {
    case ignored
    case scheduled
    case failedToSchedule
}

public protocol BackgroundRefreshScheduling: Sendable {
    func register(
        identifier: String,
        handler: @escaping @Sendable () async -> Bool
    )
    func submit(_ request: BackgroundRefreshRequest) async -> Bool
}

#if canImport(BackgroundTasks)
import BackgroundTasks

public final class LiveBackgroundRefreshScheduler: BackgroundRefreshScheduling, @unchecked Sendable {
    private var handlers: [String: @Sendable () async -> Bool] = [:]
    private let lock = NSLock()

    public init() {}

    public func register(
        identifier: String,
        handler: @escaping @Sendable () async -> Bool
    ) {
        lock.lock()
        handlers[identifier] = handler
        lock.unlock()

        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }

            refreshTask.expirationHandler = {
                refreshTask.setTaskCompleted(success: false)
            }

            Task {
                let handler = self.handler(for: identifier)
                let success = await handler?() ?? false
                refreshTask.setTaskCompleted(success: success)
            }
        }
    }

    public func submit(_ request: BackgroundRefreshRequest) async -> Bool {
        let submitRequest = BGAppRefreshTaskRequest(identifier: request.identifier)
        submitRequest.earliestBeginDate = request.earliestBeginDate
        do {
            try BGTaskScheduler.shared.submit(submitRequest)
            return true
        } catch {
            return false
        }
    }

    private func handler(for identifier: String) -> (@Sendable () async -> Bool)? {
        lock.lock()
        defer { lock.unlock() }
        return handlers[identifier]
    }
}
#endif
