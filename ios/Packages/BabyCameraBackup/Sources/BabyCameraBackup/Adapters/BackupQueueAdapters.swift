import Foundation

public actor InMemoryBackupQueueStore: BackupQueuePersisting {
    private var state: BackupQueuePersistedState

    public init(initial: BackupQueuePersistedState = BackupQueuePersistedState()) {
        self.state = initial
    }

    public func loadState() async throws -> BackupQueuePersistedState {
        state
    }

    public func saveState(_ state: BackupQueuePersistedState) async throws {
        self.state = state
    }
}

public final class UserDefaultsBackupQueueStore: BackupQueuePersisting, @unchecked Sendable {
    public static let storageKey = "com.babycamera.backup.queue.state"

    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()

    public init(
        defaults: UserDefaults = .standard,
        key: String = UserDefaultsBackupQueueStore.storageKey
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func loadState() async throws -> BackupQueuePersistedState {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: key) else {
            return BackupQueuePersistedState()
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode(BackupQueuePersistedState.self, from: data))
            ?? BackupQueuePersistedState()
    }

    public func saveState(_ state: BackupQueuePersistedState) async throws {
        lock.lock()
        defer { lock.unlock() }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(state) else { return }
        defaults.set(data, forKey: key)
    }
}

public struct StaticBackupProviderResolver: BackupProviderResolving {
    private let providersByKind: [BackupKind: any BackupProvider]

    public init(providers: [any BackupProvider]) {
        var map: [BackupKind: any BackupProvider] = [:]
        for provider in providers {
            map[provider.kind] = provider
        }
        self.providersByKind = map
    }

    public func providers(for kinds: [BackupKind]) -> [any BackupProvider] {
        kinds.compactMap { providersByKind[$0] }
    }
}

public final class MockBackupNetworkMonitor: BackupNetworkMonitoring, @unchecked Sendable {
    public private(set) var isStarted = false
    public var snapshot: BackupNetworkSnapshot
    private var onChange: (@Sendable (BackupNetworkSnapshot) -> Void)?

    public init(snapshot: BackupNetworkSnapshot = BackupNetworkSnapshot(isOnline: true, isOnWiFi: true)) {
        self.snapshot = snapshot
    }

    public func start(onChange: @escaping @Sendable (BackupNetworkSnapshot) -> Void) {
        isStarted = true
        self.onChange = onChange
        onChange(snapshot)
    }

    public func stop() {
        isStarted = false
        onChange = nil
    }

    public func currentSnapshot() async -> BackupNetworkSnapshot {
        snapshot
    }

    public func setSnapshot(_ snapshot: BackupNetworkSnapshot) {
        self.snapshot = snapshot
        onChange?(snapshot)
    }
}

public final class RecordingBackupConsecutiveFailureAlerter: BackupConsecutiveFailureAlerting, @unchecked Sendable {
    public private(set) var alertCounts: [Int] = []

    public init() {}

    public func showConsecutiveFailureAlert(consecutiveFailures: Int) async {
        alertCounts.append(consecutiveFailures)
    }
}

public final class RecordingBackupQueueSleeper: BackupQueueSleeping, @unchecked Sendable {
    public private(set) var sleptSeconds: [TimeInterval] = []

    public init() {}

    public func sleep(seconds: TimeInterval) async {
        sleptSeconds.append(seconds)
    }
}

public final class ControllableBackupClock: BackupClock, @unchecked Sendable {
    public var nowMillis: Int64

    public init(nowMillis: Int64 = 1_700_000_000_000) {
        self.nowMillis = nowMillis
    }

    public func nowUnixMillis() -> Int64 {
        nowMillis
    }

    public func advance(bySeconds seconds: TimeInterval) {
        nowMillis += Int64(seconds * 1000)
    }
}

#if canImport(Network)
import Network

public enum BackupNetworkPathHelper {
    public static func snapshot(from path: NWPath) -> BackupNetworkSnapshot {
        BackupNetworkSnapshot(
            isOnline: path.status == .satisfied,
            isOnWiFi: path.status == .satisfied && path.usesInterfaceType(.wifi)
        )
    }
}

public final class LiveBackupNetworkMonitor: BackupNetworkMonitoring, @unchecked Sendable {
    private let monitor: NWPathMonitor
    private let monitorQueue: DispatchQueue
    private var onChange: (@Sendable (BackupNetworkSnapshot) -> Void)?
    private var latestSnapshot = BackupNetworkSnapshot(isOnline: false, isOnWiFi: false)
    private var isStarted = false
    private let lock = NSLock()

    public init(
        monitor: NWPathMonitor = NWPathMonitor(),
        monitorQueue: DispatchQueue = DispatchQueue(label: "com.babycamera.backup.network")
    ) {
        self.monitor = monitor
        self.monitorQueue = monitorQueue
    }

    deinit {
        stop()
    }

    public func start(onChange: @escaping @Sendable (BackupNetworkSnapshot) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !isStarted else { return }
        isStarted = true
        self.onChange = onChange

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let snapshot = BackupNetworkPathHelper.snapshot(from: path)
            self.lock.lock()
            self.latestSnapshot = snapshot
            let handler = self.onChange
            self.lock.unlock()
            handler?(snapshot)
        }
        monitor.start(queue: monitorQueue)
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard isStarted else { return }
        isStarted = false
        monitor.cancel()
        onChange = nil
    }

    public func currentSnapshot() async -> BackupNetworkSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return latestSnapshot
    }
}
#endif
