import BabyCameraCredit
import BabyCameraNetwork
import Foundation

public enum AITaskCoordinatorError: Error, Equatable, Sendable {
    case notAuthenticated
    case taskNotTracked(String)
}

public protocol AITaskFetching: Sendable {
    func fetchTask(taskId: String) async throws -> AITaskDetailData
}

public protocol AITaskWebSocketConnecting: Sendable {
    var events: AsyncStream<AITaskEvent> { get }
    var connectionStates: AsyncStream<AIWebSocketConnectionState> { get }
    func connect(accessToken: String)
    func disconnect()
    func subscribe(taskIds: [String]) async throws
}

public protocol AITaskClock: Sendable {
    func now() -> Date
    func sleep(seconds: TimeInterval) async
}

public struct SystemAITaskClock: AITaskClock, Sendable {
    public init() {}

    public func now() -> Date { Date() }

    public func sleep(seconds: TimeInterval) async {
        let nanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

/// Local task state machine + WebSocket subscription + polling fallback + push compensation.
public actor AITaskCoordinator {
    public enum TransportMode: Sendable, Equatable {
        case webSocket
        case polling
    }

    public struct Configuration: Sendable {
        public var wsDisconnectPollingThreshold: TimeInterval
        public var pollingInterval: TimeInterval

        public init(
            wsDisconnectPollingThreshold: TimeInterval = 60,
            pollingInterval: TimeInterval = 5
        ) {
            self.wsDisconnectPollingThreshold = wsDisconnectPollingThreshold
            self.pollingInterval = pollingInterval
        }
    }

    public static let sharedEventStreamCapacity = 32

    private let configuration: Configuration
    private let taskFetcher: any AITaskFetching
    private let webSocket: any AITaskWebSocketConnecting
    private let tokenStore: TokenStore
    private let clock: any AITaskClock

    private var trackedTasks: [String: AITaskSnapshot] = [:]
    private var transportMode: TransportMode = .webSocket
    private var wsDisconnectedAt: Date?
    private var isInBackground = false
    private var isWebSocketConnected = false

    private var eventLoopTask: Task<Void, Never>?
    private var connectionLoopTask: Task<Void, Never>?
    private var pollingLoopTask: Task<Void, Never>?
    private var transportEvaluationTask: Task<Void, Never>?

    private var continuation: AsyncStream<AITaskSnapshot>.Continuation?
    public private(set) var updates: AsyncStream<AITaskSnapshot>

    public init(
        configuration: Configuration = Configuration(),
        taskFetcher: any AITaskFetching,
        webSocket: any AITaskWebSocketConnecting,
        tokenStore: TokenStore,
        clock: any AITaskClock = SystemAITaskClock()
    ) {
        self.configuration = configuration
        self.taskFetcher = taskFetcher
        self.webSocket = webSocket
        self.tokenStore = tokenStore
        self.clock = clock

        var capturedContinuation: AsyncStream<AITaskSnapshot>.Continuation?
        self.updates = AsyncStream(bufferingPolicy: .bufferingNewest(Self.sharedEventStreamCapacity)) { continuation in
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation
    }

    deinit {
        eventLoopTask?.cancel()
        connectionLoopTask?.cancel()
        pollingLoopTask?.cancel()
        transportEvaluationTask?.cancel()
        continuation?.finish()
    }

    public func currentTransportMode() -> TransportMode {
        transportMode
    }

    public func snapshot(taskId: String) -> AITaskSnapshot? {
        trackedTasks[taskId]
    }

    public func activeSnapshots() -> [AITaskSnapshot] {
        trackedTasks.values
            .filter { !$0.phase.isTerminal }
            .sorted { $0.updatedAt < $1.updatedAt }
    }

    /// Begin tracking a newly submitted task.
    public func track(created: AITaskCreatedData) async throws {
        let snapshot = AITaskSnapshot(created: created, updatedAt: clock.now())
        trackedTasks[created.taskId] = snapshot
        publish(snapshot)
        try await ensureTransportReady(subscribeTaskIds: [created.taskId])
    }

    public func stopTracking(taskId: String) {
        trackedTasks.removeValue(forKey: taskId)
        if activeTaskIDs().isEmpty {
            stopPollingLoop()
            webSocket.disconnect()
        }
    }

    public func applicationDidEnterBackground() {
        isInBackground = true
        webSocket.disconnect()
        isWebSocketConnected = false
    }

    /// Reconnect transport and refresh in-flight tasks when returning to foreground.
    public func applicationWillEnterForeground() async throws {
        isInBackground = false
        wsDisconnectedAt = nil
        transportMode = .webSocket
        stopPollingLoop()
        try await refreshActiveTasks()
        try await ensureTransportReady(subscribeTaskIds: activeTaskIDs())
    }

    /// Apply silent push compensation while app is backgrounded or WS is unavailable.
    public func handlePushNotification(_ payload: AITaskPushPayload) async {
        guard trackedTasks[payload.taskId] != nil else { return }
        let snapshot = AITaskSnapshot(
            taskId: payload.taskId,
            phase: AITaskPhaseMapper.phase(forServerState: payload.state),
            serverState: payload.state,
            resultUrl: payload.resultUrl,
            thumbnailUrl: payload.thumbnailUrl,
            updatedAt: clock.now()
        )
        trackedTasks[payload.taskId] = snapshot
        publish(snapshot)
        if snapshot.phase.isTerminal {
            stopPollingLoop()
        }
    }

    /// Mark a succeeded task as downloaded after local persistence completes.
    public func markDownloaded(taskId: String) {
        guard let existing = trackedTasks[taskId] else { return }
        let snapshot = AITaskSnapshot(
            taskId: taskId,
            phase: .downloaded,
            serverState: existing.serverState,
            resultUrl: existing.resultUrl,
            thumbnailUrl: existing.thumbnailUrl,
            deepSynth: existing.deepSynth,
            costCredits: existing.costCredits,
            balanceAfter: existing.balanceAfter,
            failureReason: existing.failureReason,
            updatedAt: clock.now()
        )
        trackedTasks[taskId] = snapshot
        publish(snapshot)
    }

    private func ensureTransportReady(subscribeTaskIds: [String]) async throws {
        guard let token = tokenStore.accessToken() else {
            throw AITaskCoordinatorError.notAuthenticated
        }

        startMonitoringIfNeeded()
        webSocket.connect(accessToken: token)
        if !subscribeTaskIds.isEmpty {
            try await webSocket.subscribe(taskIds: subscribeTaskIds)
        }
    }

    private func startMonitoringIfNeeded() {
        if eventLoopTask == nil {
            let events = webSocket.events
            eventLoopTask = Task { [weak self] in
                for await event in events {
                    await self?.handleWebSocketEvent(event)
                }
            }
        }

        if connectionLoopTask == nil {
            let connectionStates = webSocket.connectionStates
            connectionLoopTask = Task { [weak self] in
                for await state in connectionStates {
                    await self?.handleConnectionState(state)
                }
            }
        }
    }

    private func handleWebSocketEvent(_ event: AITaskEvent) {
        guard trackedTasks[event.taskId] != nil else { return }
        let snapshot = AITaskSnapshot(taskId: event.taskId, event: event, updatedAt: clock.now())
        trackedTasks[event.taskId] = snapshot
        publish(snapshot)
        if snapshot.phase.isTerminal {
            evaluatePollingStop()
        }
    }

    private func handleConnectionState(_ state: AIWebSocketConnectionState) {
        switch state {
        case .connected:
            isWebSocketConnected = true
            wsDisconnectedAt = nil
            if transportMode == .polling {
                transportMode = .webSocket
                stopPollingLoop()
            }
        case .disconnected:
            isWebSocketConnected = false
            if wsDisconnectedAt == nil {
                wsDisconnectedAt = clock.now()
            }
            scheduleTransportEvaluation()
        }
    }

    private func scheduleTransportEvaluation() {
        transportEvaluationTask?.cancel()
        transportEvaluationTask = Task { [weak self] in
            guard let self else { return }
            await self.clock.sleep(seconds: await self.configuration.wsDisconnectPollingThreshold)
            await self.evaluatePollingFallback()
        }
    }

    private func evaluatePollingFallback() {
        guard !isWebSocketConnected else { return }
        guard activeTaskIDs().isEmpty == false else { return }

        if let disconnectedAt = wsDisconnectedAt,
           clock.now().timeIntervalSince(disconnectedAt) >= configuration.wsDisconnectPollingThreshold {
            transportMode = .polling
            startPollingLoopIfNeeded()
        }
    }

    private func evaluatePollingStop() {
        if activeTaskIDs().isEmpty {
            stopPollingLoop()
        }
    }

    private func startPollingLoopIfNeeded() {
        guard pollingLoopTask == nil else { return }
        pollingLoopTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshActiveTasks()
                let interval = await self.configuration.pollingInterval
                await self.clock.sleep(seconds: interval)
                if await self.activeTaskIDs().isEmpty {
                    await self.stopPollingLoop()
                    return
                }
            }
        }
    }

    private func stopPollingLoop() {
        pollingLoopTask?.cancel()
        pollingLoopTask = nil
    }

    private func refreshActiveTasks() async {
        for taskId in activeTaskIDs() {
            do {
                let detail = try await taskFetcher.fetchTask(taskId: taskId)
                let snapshot = AITaskSnapshot(taskId: taskId, detail: detail, updatedAt: clock.now())
                trackedTasks[taskId] = snapshot
                publish(snapshot)
            } catch {
                continue
            }
        }
        evaluatePollingStop()
    }

    private func activeTaskIDs() -> [String] {
        trackedTasks.values
            .filter { !$0.phase.isTerminal }
            .map(\.taskId)
    }

    private func publish(_ snapshot: AITaskSnapshot) {
        continuation?.yield(snapshot)
    }
}

extension AITasksAPI: AITaskFetching {
    public func fetchTask(taskId: String) async throws -> AITaskDetailData {
        try await getTask(taskId: taskId)
    }
}

extension AIWebSocketClient: AITaskWebSocketConnecting {}

public struct LiveAITaskCoordinatorFactory {
    @MainActor
    public static func make(
        region: AppRegion = .cn,
        tokenStore: TokenStore = KeychainTokenStore(),
        regionConfig: RegionConfig? = nil,
        session: URLSession = .shared,
        configuration: AITaskCoordinator.Configuration = .init(),
        creditService: CreditService? = nil
    ) -> AITaskCoordinator {
        let config = regionConfig ?? RegionConfig(region: region, appVersion: "1.0.0", deviceId: "ai-task-device")
        let client = makeAuthenticatedClient(
            region: region,
            tokenStore: tokenStore,
            regionConfig: config,
            session: session
        )
        let api = AITasksAPI(client: client)
        let webSocket = AIWebSocketClient(
            configuration: AIWebSocketClient.Configuration(region: region),
            session: session
        )
        if let creditService {
            AIPlayCreditBinding.bind(creditService: creditService, taskEvents: webSocket.events)
        }
        return AITaskCoordinator(
            configuration: configuration,
            taskFetcher: api,
            webSocket: webSocket,
            tokenStore: tokenStore
        )
    }
}
