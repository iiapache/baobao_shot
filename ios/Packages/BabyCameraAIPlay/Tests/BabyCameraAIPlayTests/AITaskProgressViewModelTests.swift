import BabyCameraCredit
import BabyCameraNetwork
import XCTest
@testable import BabyCameraAIPlay

@MainActor
final class AITaskProgressViewModelTests: XCTestCase {
    private let created = AITaskCreatedData(
        taskId: "tsk_progress_001",
        state: "credit_held",
        costCredits: 8,
        balanceAfter: 92,
        estimatedSeconds: 18
    )

    func testModelFailedShowsFailureAndRefundHint() async throws {
        let webSocket = ProgressMockWebSocket()
        let coordinator = makeCoordinator(webSocket: webSocket)
        try await coordinator.track(created: created)

        let viewModel = makeViewModel(coordinator: coordinator)
        await viewModel.start()

        webSocket.emit(
            AITaskEvent(
                taskId: created.taskId,
                state: "failed",
                costCredits: 8,
                balanceAfter: 100
            )
        )
        try await Task.sleep(nanoseconds: 80_000_000)

        guard case let .failure(presentation) = viewModel.state else {
            return XCTFail("expected failure state, got \(viewModel.state)")
        }
        XCTAssertEqual(presentation.kind, .modelFailed)
        XCTAssertEqual(presentation.creditRefund?.refundedCredits, 8)
        XCTAssertFalse(presentation.canAppeal)
    }

    func testRejectedShowsAppealEntryAndRefundHint() async throws {
        let webSocket = ProgressMockWebSocket()
        let coordinator = makeCoordinator(webSocket: webSocket)
        try await coordinator.track(created: created)

        let viewModel = makeViewModel(coordinator: coordinator)
        await viewModel.start()

        webSocket.emit(
            AITaskEvent(
                taskId: created.taskId,
                state: "rejected",
                costCredits: 8,
                balanceAfter: 100
            )
        )
        try await Task.sleep(nanoseconds: 80_000_000)

        guard case let .failure(presentation) = viewModel.state else {
            return XCTFail("expected failure state")
        }
        XCTAssertEqual(presentation.kind, .rejected)
        XCTAssertTrue(presentation.canAppeal)
        XCTAssertEqual(presentation.creditRefund?.message, "已退还 8 积分，当前余额 100 积分")
    }

    func testRefundedBalanceReflectedInPresentation() async throws {
        let webSocket = ProgressMockWebSocket()
        let coordinator = makeCoordinator(webSocket: webSocket)
        try await coordinator.track(created: created)

        let viewModel = makeViewModel(coordinator: coordinator)
        await viewModel.start()

        webSocket.emit(
            AITaskEvent(
                taskId: created.taskId,
                state: "failed",
                costCredits: 10,
                balanceAfter: 110
            )
        )
        try await Task.sleep(nanoseconds: 80_000_000)

        guard case let .failure(presentation) = viewModel.state else {
            return XCTFail("expected failure state")
        }
        XCTAssertEqual(presentation.creditRefund?.refundedCredits, 10)
        XCTAssertEqual(presentation.creditRefund?.balanceAfter, 110)
    }

    func testFailureAppliesRefundedBalanceToCreditService() async throws {
        let creditService = ProgressMockCreditService(initialBalance: 82)
        let webSocket = ProgressMockWebSocket()
        let coordinator = makeCoordinator(webSocket: webSocket)
        try await coordinator.track(created: created)

        let viewModel = makeViewModel(coordinator: coordinator, creditService: creditService)
        await viewModel.start()

        XCTAssertEqual(creditService.balance, 92)

        webSocket.emit(
            AITaskEvent(
                taskId: created.taskId,
                state: "failed",
                costCredits: 8,
                balanceAfter: 100
            )
        )
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(creditService.balance, 100)
    }

    func testSubmitAppealTransitionsToAppealed() async throws {
        let webSocket = ProgressMockWebSocket()
        let coordinator = makeCoordinator(webSocket: webSocket)
        try await coordinator.track(created: created)

        let appealService = ProgressMockAppealService(
            result: .success(
                AITaskAppealData(
                    taskId: "tsk_progress_001",
                    state: "appealed",
                    appealId: "apl_test_001"
                )
            )
        )
        let viewModel = makeViewModel(coordinator: coordinator, appealService: appealService)
        await viewModel.start()

        webSocket.emit(
            AITaskEvent(
                taskId: created.taskId,
                state: "rejected",
                costCredits: 8,
                balanceAfter: 100
            )
        )
        try await Task.sleep(nanoseconds: 80_000_000)

        viewModel.appealReason = "误判，内容为正常宝宝照片"
        await viewModel.submitAppeal()

        guard case let .failure(presentation) = viewModel.state else {
            return XCTFail("expected appealed failure state")
        }
        XCTAssertEqual(presentation.kind, .appealed)
        XCTAssertEqual(viewModel.snapshot?.serverState, "appealed")
        XCTAssertEqual(appealService.lastReason, "误判，内容为正常宝宝照片")
    }

    func testSubmitAppealRequiresReason() async throws {
        let webSocket = ProgressMockWebSocket()
        let coordinator = makeCoordinator(webSocket: webSocket)
        try await coordinator.track(created: created)

        let viewModel = makeViewModel(coordinator: coordinator)
        await viewModel.start()

        webSocket.emit(
            AITaskEvent(
                taskId: created.taskId,
                state: "rejected",
                costCredits: 8,
                balanceAfter: 100
            )
        )
        try await Task.sleep(nanoseconds: 80_000_000)

        viewModel.appealReason = "   "
        await viewModel.submitAppeal()

        XCTAssertEqual(viewModel.appealErrorMessage, "请填写申诉原因")
        guard case let .failure(presentation) = viewModel.state else {
            return XCTFail("expected rejected failure state")
        }
        XCTAssertEqual(presentation.kind, .rejected)
    }

    private func makeCoordinator(webSocket: ProgressMockWebSocket) -> AITaskCoordinator {
        AITaskCoordinator(
            taskFetcher: ProgressMockFetcher(),
            webSocket: webSocket,
            tokenStore: InMemoryTokenStore(access: "access-token", refresh: "refresh-token")
        )
    }

    private func makeViewModel(
        coordinator: AITaskCoordinator,
        appealService: ProgressMockAppealService = ProgressMockAppealService(),
        creditService: ProgressMockCreditService? = nil
    ) -> AITaskProgressViewModel {
        AITaskProgressViewModel(
            created: created,
            playName: "宫崎骏风",
            coordinator: coordinator,
            appealService: appealService,
            creditService: creditService
        )
    }
}

@MainActor
private final class ProgressMockCreditService: CreditServing {
    var balance: Int
    var signInAvailable: Bool = false
    var currentSignInStreak: Int = 0

    init(initialBalance: Int) {
        balance = initialBalance
    }

    func refreshBalance() async throws {}
    func signIn() async throws -> SignInResult {
        throw CreditServiceError.notAuthenticated
    }
    func fetchTransactions(cursor: String?, limit: Int) async throws -> CreditTransactionsPage {
        CreditTransactionsPage(items: [], nextCursor: nil)
    }
    func bindWebSocketEvents(_ events: AsyncStream<AITaskBalanceEvent>) {}
    func unbindWebSocketEvents() {}
    func applyBalanceFromAITask(_ balanceAfter: Int) {
        balance = balanceAfter
    }
    func previewCost(playId: String, durationSeconds: Int?, localCost: Int) async throws -> CreditCostPreview {
        CreditCostPreview(costCredits: localCost, balance: balance, signInAvailable: signInAvailable)
    }
}

private final class ProgressMockFetcher: AITaskFetching, @unchecked Sendable {
    func fetchTask(taskId: String) async throws -> AITaskDetailData {
        AITaskDetailData(taskId: taskId, state: "running")
    }
}

private final class ProgressMockWebSocket: AITaskWebSocketConnecting, @unchecked Sendable {
    private let lock = NSLock()
    private var eventsContinuation: AsyncStream<AITaskEvent>.Continuation?

    lazy var events: AsyncStream<AITaskEvent> = {
        AsyncStream { continuation in
            lock.lock()
            eventsContinuation = continuation
            lock.unlock()
        }
    }()

    lazy var connectionStates: AsyncStream<AIWebSocketConnectionState> = {
        AsyncStream { _ in }
    }()

    func connect(accessToken: String) {}
    func disconnect() {}
    func subscribe(taskIds: [String]) async throws {}

    func emit(_ event: AITaskEvent) {
        lock.lock()
        let continuation = eventsContinuation
        lock.unlock()
        continuation?.yield(event)
    }
}

private final class ProgressMockAppealService: AITaskAppealing, @unchecked Sendable {
    let result: Result<AITaskAppealData, Error>?
    private(set) var lastReason: String?

    init(result: Result<AITaskAppealData, Error>? = nil) {
        self.result = result
    }

    func appeal(taskId: String, reason: String) async throws -> AITaskAppealData {
        lastReason = reason
        if let result {
            return try result.get()
        }
        return AITaskAppealData(taskId: taskId, state: "appealed", appealId: "apl_default")
    }
}
