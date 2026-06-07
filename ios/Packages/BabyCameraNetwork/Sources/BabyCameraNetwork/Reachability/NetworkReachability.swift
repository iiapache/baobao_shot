import Combine
import Foundation

#if canImport(Network)
import Network

/// 基于 `NWPathMonitor` 的网络可达性观察器，供 Timeline / Feed 离线指示与联网恢复刷新。
@MainActor
public final class NetworkReachability: ObservableObject {
    @Published public private(set) var isOnline = true

    private let monitor: NWPathMonitor
    private let monitorQueue: DispatchQueue
    private var isStarted = false
    private var wasOffline = false
    private var reconnectHandlers: [UUID: () -> Void] = [:]

    public init(
        monitor: NWPathMonitor = NWPathMonitor(),
        monitorQueue: DispatchQueue = DispatchQueue(label: "com.babycamera.network.reachability")
    ) {
        self.monitor = monitor
        self.monitorQueue = monitorQueue
    }

    deinit {
        monitor.cancel()
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    public func stop() {
        guard isStarted else { return }
        isStarted = false
        monitor.cancel()
    }

    /// 注册联网恢复回调（离线 → 在线时触发）。
    @discardableResult
    public func onReconnect(_ handler: @escaping @MainActor () -> Void) -> UUID {
        let id = UUID()
        reconnectHandlers[id] = handler
        return id
    }

    public func removeReconnectHandler(_ id: UUID) {
        reconnectHandlers.removeValue(forKey: id)
    }

    private func handlePathUpdate(_ path: NWPath) {
        let online = path.status == .satisfied
        if online, wasOffline {
            reconnectHandlers.values.forEach { $0() }
        }
        isOnline = online
        wasOffline = !online
    }
}

#else

@MainActor
public final class NetworkReachability: ObservableObject {
    @Published public private(set) var isOnline = true

    public init() {}

    public func start() {}
    public func stop() {}

    @discardableResult
    public func onReconnect(_ handler: @escaping @MainActor () -> Void) -> UUID {
        UUID()
    }

    public func removeReconnectHandler(_ id: UUID) {}
}

#endif
