import Foundation
import Network

/// Observes network reachability and triggers incremental sync when connectivity returns.
public final class BackgroundSyncService: @unchecked Sendable {
    private let coordinator: SyncCoordinator
    private let monitor: NWPathMonitor
    private let monitorQueue: DispatchQueue
    private let syncQueue: DispatchQueue

    private var isMonitoring = false
    private var wasOffline = true
    private var syncTask: Task<Void, Never>?

    public init(
        coordinator: SyncCoordinator,
        monitor: NWPathMonitor = NWPathMonitor(),
        monitorQueue: DispatchQueue = DispatchQueue(label: "com.babycamera.sync.monitor"),
        syncQueue: DispatchQueue = DispatchQueue(label: "com.babycamera.sync.pull")
    ) {
        self.coordinator = coordinator
        self.monitor = monitor
        self.monitorQueue = monitorQueue
        self.syncQueue = syncQueue
    }

    deinit {
        stop()
    }

    public func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        wasOffline = true

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let isOnline = path.status == .satisfied
            if isOnline && self.wasOffline {
                self.scheduleSync()
            }
            self.wasOffline = !isOnline
        }
        monitor.start(queue: monitorQueue)
    }

    public func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        monitor.cancel()
        syncTask?.cancel()
        syncTask = nil
    }

    public func syncNow() {
        scheduleSync()
    }

    private func scheduleSync() {
        syncTask?.cancel()
        syncTask = Task { [coordinator, syncQueue] in
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                syncQueue.async {
                    continuation.resume()
                }
            }
            guard !Task.isCancelled else { return }
            _ = try? await coordinator.pullIncremental()
        }
    }
}
