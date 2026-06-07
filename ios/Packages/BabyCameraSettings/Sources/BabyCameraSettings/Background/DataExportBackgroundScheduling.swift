import Foundation

public struct DataExportBackgroundRequest: Sendable, Equatable {
    public let identifier: String
    public let requiresExternalPower: Bool
    public let requiresNetworkConnectivity: Bool

    public init(
        identifier: String,
        requiresExternalPower: Bool = false,
        requiresNetworkConnectivity: Bool = false
    ) {
        self.identifier = identifier
        self.requiresExternalPower = requiresExternalPower
        self.requiresNetworkConnectivity = requiresNetworkConnectivity
    }
}

public enum DataExportBackgroundHandlingResult: Sendable, Equatable {
    case ignored
    case scheduled
    case failedToSchedule
}

public protocol DataExportBackgroundScheduling: Sendable {
    func register(
        identifier: String,
        handler: @escaping @Sendable () async -> Bool
    )
    func submit(_ request: DataExportBackgroundRequest) async -> Bool
}

#if canImport(BackgroundTasks)
import BackgroundTasks

public final class LiveDataExportBackgroundScheduler: DataExportBackgroundScheduling, @unchecked Sendable {
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
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }

            processingTask.expirationHandler = {
                processingTask.setTaskCompleted(success: false)
            }

            Task {
                let handler = self.handler(for: identifier)
                let success = await handler?() ?? false
                processingTask.setTaskCompleted(success: success)
            }
        }
    }

    public func submit(_ request: DataExportBackgroundRequest) async -> Bool {
        let submitRequest = BGProcessingTaskRequest(identifier: request.identifier)
        submitRequest.requiresExternalPower = request.requiresExternalPower
        submitRequest.requiresNetworkConnectivity = request.requiresNetworkConnectivity
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

/// 测试与 Preview 使用的内存调度器。
public final class InMemoryDataExportBackgroundScheduler: DataExportBackgroundScheduling, @unchecked Sendable {
    private var handlers: [String: @Sendable () async -> Bool] = [:]
    private var submittedRequests: [DataExportBackgroundRequest] = []
    private let lock = NSLock()

    public init() {}

    public func register(
        identifier: String,
        handler: @escaping @Sendable () async -> Bool
    ) {
        lock.lock()
        handlers[identifier] = handler
        lock.unlock()
    }

    public func submit(_ request: DataExportBackgroundRequest) async -> Bool {
        lock.lock()
        submittedRequests.append(request)
        let handler = handlers[request.identifier]
        lock.unlock()

        if let handler {
            return await handler()
        }
        return true
    }

    public var lastSubmittedRequest: DataExportBackgroundRequest? {
        lock.lock()
        defer { lock.unlock() }
        return submittedRequests.last
    }
}
