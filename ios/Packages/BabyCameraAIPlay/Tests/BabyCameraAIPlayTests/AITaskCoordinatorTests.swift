import BabyCameraNetwork
import XCTest
@testable import BabyCameraAIPlay

final class AITaskPhaseMapperTests: XCTestCase {
    func testPendingStates() {
        XCTAssertEqual(AITaskPhaseMapper.phase(forServerState: "credit_held"), .submitted)
        XCTAssertEqual(AITaskPhaseMapper.phase(forServerState: "queued"), .pending)
    }

    func testRunningStates() {
        XCTAssertEqual(AITaskPhaseMapper.phase(forServerState: "running"), .running)
        XCTAssertEqual(AITaskPhaseMapper.phase(forServerState: "watermarking"), .running)
    }

    func testTerminalStates() {
        XCTAssertEqual(AITaskPhaseMapper.phase(forServerState: "succeeded"), .succeeded)
        XCTAssertEqual(AITaskPhaseMapper.phase(forServerState: "failed"), .failed)
        XCTAssertEqual(AITaskPhaseMapper.phase(forServerState: "rejected"), .rejected)
        XCTAssertEqual(AITaskPhaseMapper.phase(forServerState: "appealed"), .appealed)
        XCTAssertEqual(AITaskPhaseMapper.phase(forServerState: "model_failed"), .running)
        XCTAssertTrue(AITaskPhaseMapper.isTerminalServerState("succeeded"))
        XCTAssertTrue(AITaskPhaseMapper.isTerminalServerState("appealed"))
        XCTAssertFalse(AITaskPhaseMapper.isTerminalServerState("running"))
        XCTAssertFalse(AITaskPhaseMapper.isTerminalServerState("model_failed"))
    }
}

final class AITaskCoordinatorTests: XCTestCase {
    func testTrackAndReceiveWebSocketEvent() async throws {
        let webSocket = MockAITaskWebSocket()
        let fetcher = MockAITaskFetcher()
        let tokenStore = InMemoryTokenStore(access: "access-token", refresh: "refresh-token")
        let coordinator = makeCoordinator(
            fetcher: fetcher,
            webSocket: webSocket,
            tokenStore: tokenStore
        )

        try await coordinator.track(
            created: AITaskCreatedData(
                taskId: "tsk_ws_001",
                state: "credit_held",
                costCredits: 8,
                balanceAfter: 92
            )
        )

        XCTAssertEqual(await coordinator.snapshot(taskId: "tsk_ws_001")?.phase, .submitted)
        XCTAssertEqual(webSocket.connectCount, 1)
        XCTAssertEqual(webSocket.subscribedTaskIDs, ["tsk_ws_001"])

        webSocket.emit(
            AITaskEvent(
                taskId: "tsk_ws_001",
                state: "running"
            )
        )
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(await coordinator.snapshot(taskId: "tsk_ws_001")?.phase, .running)

        webSocket.emit(
            AITaskEvent(
                taskId: "tsk_ws_001",
                state: "succeeded",
                resultUrl: "https://cdn.example/result.heic",
                thumbnailUrl: "https://cdn.example/thumb.jpg",
                costCredits: 8,
                balanceAfter: 92
            )
        )
        try await Task.sleep(nanoseconds: 50_000_000)

        let snapshot = await coordinator.snapshot(taskId: "tsk_ws_001")
        XCTAssertEqual(snapshot?.phase, .succeeded)
        XCTAssertEqual(snapshot?.resultUrl, "https://cdn.example/result.heic")
    }

    func testPollingFallbackAfterWebSocketDisconnectThreshold() async throws {
        let webSocket = MockAITaskWebSocket()
        let fetcher = MockAITaskFetcher(
            responses: [
                "tsk_poll_001": AITaskDetailData(
                    taskId: "tsk_poll_001",
                    state: "succeeded",
                    resultUrl: "https://cdn.example/polled.heic"
                ),
            ]
        )
        let clock = MockAITaskClock()
        let coordinator = makeCoordinator(
            fetcher: fetcher,
            webSocket: webSocket,
            clock: clock,
            configuration: AITaskCoordinator.Configuration(
                wsDisconnectPollingThreshold: 0.05,
                pollingInterval: 0.02
            )
        )

        try await coordinator.track(
            created: AITaskCreatedData(
                taskId: "tsk_poll_001",
                state: "running",
                costCredits: 8,
                balanceAfter: 92
            )
        )

        webSocket.emitConnection(.disconnected)
        clock.advance(by: 0.06)
        try await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(await coordinator.currentTransportMode(), .polling)
        let snapshot = await coordinator.snapshot(taskId: "tsk_poll_001")
        XCTAssertEqual(snapshot?.phase, .succeeded)
        XCTAssertEqual(snapshot?.resultUrl, "https://cdn.example/polled.heic")
        XCTAssertGreaterThanOrEqual(fetcher.fetchCount(for: "tsk_poll_001"), 1)
    }

    func testBackgroundPushAndForegroundStillHasResult() async throws {
        let webSocket = MockAITaskWebSocket()
        let fetcher = MockAITaskFetcher()
        let coordinator = makeCoordinator(fetcher: fetcher, webSocket: webSocket)

        try await coordinator.track(
            created: AITaskCreatedData(
                taskId: "tsk_bg_001",
                state: "running",
                costCredits: 8,
                balanceAfter: 92
            )
        )

        await coordinator.applicationDidEnterBackground()
        XCTAssertEqual(webSocket.disconnectCount, 1)

        await coordinator.handlePushNotification(
            AITaskPushPayload(
                taskId: "tsk_bg_001",
                state: "succeeded",
                resultUrl: "https://cdn.example/bg.heic",
                thumbnailUrl: "https://cdn.example/bg-thumb.jpg"
            )
        )

        let pushed = await coordinator.snapshot(taskId: "tsk_bg_001")
        XCTAssertEqual(pushed?.phase, .succeeded)
        XCTAssertEqual(pushed?.resultUrl, "https://cdn.example/bg.heic")

        try await coordinator.applicationWillEnterForeground()
        let foreground = await coordinator.snapshot(taskId: "tsk_bg_001")
        XCTAssertEqual(foreground?.phase, .succeeded)
        XCTAssertEqual(foreground?.resultUrl, "https://cdn.example/bg.heic")
    }

    func testForegroundReconnectsWebSocketForActiveTasks() async throws {
        let webSocket = MockAITaskWebSocket()
        let fetcher = MockAITaskFetcher()
        let tokenStore = InMemoryTokenStore(access: "access-token", refresh: "refresh-token")
        let coordinator = makeCoordinator(
            fetcher: fetcher,
            webSocket: webSocket,
            tokenStore: tokenStore
        )

        try await coordinator.track(
            created: AITaskCreatedData(
                taskId: "tsk_fg_001",
                state: "queued",
                costCredits: 8,
                balanceAfter: 92
            )
        )
        let connectCountBeforeBackground = webSocket.connectCount

        await coordinator.applicationDidEnterBackground()
        try await coordinator.applicationWillEnterForeground()

        XCTAssertGreaterThan(webSocket.connectCount, connectCountBeforeBackground)
        XCTAssertEqual(webSocket.subscribedTaskIDs, ["tsk_fg_001"])
    }

    func testTrackRequiresAuthentication() async {
        let coordinator = makeCoordinator(
            fetcher: MockAITaskFetcher(),
            webSocket: MockAITaskWebSocket(),
            tokenStore: InMemoryTokenStore()
        )

        do {
            try await coordinator.track(
                created: AITaskCreatedData(
                    taskId: "tsk_auth",
                    state: "credit_held",
                    costCredits: 8,
                    balanceAfter: 92
                )
            )
            XCTFail("expected notAuthenticated")
        } catch let error as AITaskCoordinatorError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    private func makeCoordinator(
        fetcher: MockAITaskFetcher,
        webSocket: MockAITaskWebSocket,
        tokenStore: TokenStore = InMemoryTokenStore(access: "access-token", refresh: "refresh-token"),
        clock: MockAITaskClock = MockAITaskClock(),
        configuration: AITaskCoordinator.Configuration = .init(
            wsDisconnectPollingThreshold: 60,
            pollingInterval: 5
        )
    ) -> AITaskCoordinator {
        AITaskCoordinator(
            configuration: configuration,
            taskFetcher: fetcher,
            webSocket: webSocket,
            tokenStore: tokenStore,
            clock: clock
        )
    }
}

private final class MockAITaskFetcher: AITaskFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [String: AITaskDetailData]
    private var counts: [String: Int] = [:]

    init(responses: [String: AITaskDetailData] = [:]) {
        self.responses = responses
    }

    func fetchTask(taskId: String) async throws -> AITaskDetailData {
        lock.lock()
        counts[taskId, default: 0] += 1
        let response = responses[taskId]
        lock.unlock()
        if let response {
            return response
        }
        return AITaskDetailData(taskId: taskId, state: "running")
    }

    func fetchCount(for taskId: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return counts[taskId, default: 0]
    }
}

private final class MockAITaskWebSocket: AITaskWebSocketConnecting, @unchecked Sendable {
    private let lock = NSLock()
    private var eventsContinuation: AsyncStream<AITaskEvent>.Continuation?
    private var connectionContinuation: AsyncStream<AIWebSocketConnectionState>.Continuation?

    private(set) var connectCount = 0
    private(set) var disconnectCount = 0
    private(set) var subscribedTaskIDs: [String] = []

    lazy var events: AsyncStream<AITaskEvent> = {
        AsyncStream { continuation in
            lock.lock()
            eventsContinuation = continuation
            lock.unlock()
        }
    }()

    lazy var connectionStates: AsyncStream<AIWebSocketConnectionState> = {
        AsyncStream { continuation in
            lock.lock()
            connectionContinuation = continuation
            lock.unlock()
        }
    }()

    func connect(accessToken: String) {
        lock.lock()
        connectCount += 1
        lock.unlock()
        emitConnection(.connected)
    }

    func disconnect() {
        lock.lock()
        disconnectCount += 1
        lock.unlock()
        emitConnection(.disconnected)
    }

    func subscribe(taskIds: [String]) async throws {
        lock.lock()
        subscribedTaskIDs = taskIds
        lock.unlock()
    }

    func emit(_ event: AITaskEvent) {
        lock.lock()
        let continuation = eventsContinuation
        lock.unlock()
        continuation?.yield(event)
    }

    func emitConnection(_ state: AIWebSocketConnectionState) {
        lock.lock()
        let continuation = connectionContinuation
        lock.unlock()
        continuation?.yield(state)
    }
}

private final class MockAITaskClock: AITaskClock, @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date()

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func sleep(seconds: TimeInterval) async {
        advance(by: seconds)
        try? await Task.sleep(nanoseconds: 10_000_000)
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        current.addTimeInterval(interval)
        lock.unlock()
    }
}
