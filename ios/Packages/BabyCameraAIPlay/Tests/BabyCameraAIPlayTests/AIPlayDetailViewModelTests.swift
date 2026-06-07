import BabyCameraCredit
import BabyCameraNetwork
import XCTest
@testable import BabyCameraAIPlay

@MainActor
final class AIPlayDetailViewModelTests: XCTestCase {
    private let play = AIPlay(
        id: "ghibli_kid",
        name: "宫崎骏风",
        kind: .image,
        creditCost: 8,
        available: true
    )

    private let context = AIPlaySubmissionContext(
        inputObjectKey: "ai-tmp/usr_test/photo.heic",
        familyId: "fam_test_001"
    )

    func testLoadPreviewWithSufficientCredit() async {
        let viewModel = makeViewModel(
            preview: CreditPreview(costCredits: 8, balance: 100, signInAvailable: false)
        )

        await viewModel.loadPreview()

        XCTAssertEqual(viewModel.preview?.costCredits, 8)
        XCTAssertEqual(viewModel.preview?.balance, 100)
        XCTAssertTrue(viewModel.preview?.hasSufficientCredit == true)
        XCTAssertEqual(viewModel.state, .ready)
        XCTAssertNil(viewModel.pendingNavigation)
    }

    func testRequestSubmitShowsConfirmationWhenCreditSufficient() async {
        let viewModel = makeViewModel(
            preview: CreditPreview(costCredits: 8, balance: 100, signInAvailable: false)
        )
        await viewModel.loadPreview()

        viewModel.requestSubmit()

        XCTAssertEqual(viewModel.state, .confirming)
        XCTAssertNil(viewModel.pendingNavigation)
    }

    func testRequestSubmitNavigatesToRechargeWhenInsufficient() async {
        let viewModel = makeViewModel(
            preview: CreditPreview(costCredits: 8, balance: 5, signInAvailable: true)
        )
        await viewModel.loadPreview()

        viewModel.requestSubmit()

        XCTAssertEqual(viewModel.pendingNavigation, .recharge)
        XCTAssertEqual(viewModel.state, .ready)
        XCTAssertEqual(viewModel.preview?.signInHint, "今日签到可领 5–20 积分")
    }

    func testConfirmSubmitCreatesTask() async {
        let expected = AITaskCreatedData(
            taskId: "tsk_test_001",
            state: "credit_held",
            costCredits: 8,
            balanceAfter: 92,
            estimatedSeconds: 18
        )
        let viewModel = makeViewModel(
            preview: CreditPreview(costCredits: 8, balance: 100, signInAvailable: false),
            submitResult: .success(expected)
        )
        await viewModel.loadPreview()
        viewModel.requestSubmit()

        await viewModel.confirmSubmit()

        XCTAssertEqual(viewModel.state, .submitted)
        XCTAssertEqual(viewModel.createdTask, expected)
    }

    func testConfirmSubmitAppliesBalanceToCreditService() async {
        let creditService = DetailMockCreditService()
        let expected = AITaskCreatedData(
            taskId: "tsk_test_001",
            state: "credit_held",
            costCredits: 8,
            balanceAfter: 92,
            estimatedSeconds: 18
        )
        let viewModel = makeViewModel(
            preview: CreditPreview(costCredits: 8, balance: 100, signInAvailable: false),
            submitResult: .success(expected),
            creditService: creditService
        )
        await viewModel.loadPreview()
        viewModel.requestSubmit()

        await viewModel.confirmSubmit()

        XCTAssertEqual(creditService.balance, 92)
    }

    func testConfirmSubmitNavigatesToRechargeOnInsufficientAPIError() async {
        let viewModel = makeViewModel(
            preview: CreditPreview(costCredits: 8, balance: 100, signInAvailable: false),
            submitResult: .failure(
                APIError(code: .aiInsufficientCredit, message: "积分不足", httpStatusCode: 422)
            )
        )
        await viewModel.loadPreview()
        viewModel.requestSubmit()

        await viewModel.confirmSubmit()

        XCTAssertEqual(viewModel.pendingNavigation, .recharge)
        XCTAssertEqual(viewModel.state, .ready)
        XCTAssertNil(viewModel.createdTask)
    }

    func testLoadPreviewMapsNetworkError() async {
        let viewModel = makeViewModel(previewResult: .failure(URLError(.notConnectedToInternet)))

        await viewModel.loadPreview()

        XCTAssertEqual(viewModel.state.errorMessage, "操作失败，请稍后重试")
        XCTAssertNil(viewModel.preview)
    }

    func testRequestSignInSetsNavigation() async {
        let viewModel = makeViewModel(
            preview: CreditPreview(costCredits: 8, balance: 5, signInAvailable: true)
        )
        await viewModel.loadPreview()

        viewModel.requestSignIn()

        XCTAssertEqual(viewModel.pendingNavigation, .signIn)
    }

    private func makeViewModel(
        preview: CreditPreview? = nil,
        previewResult: Result<CreditPreview, Error>? = nil,
        submitResult: Result<AITaskCreatedData, Error>? = nil,
        creditService: DetailMockCreditService? = nil
    ) -> AIPlayDetailViewModel {
        AIPlayDetailViewModel(
            play: play,
            submissionContext: context,
            previewService: MockCreditPreviewService(
                preview: preview,
                result: previewResult
            ),
            submitService: MockAITaskSubmitService(result: submitResult),
            creditService: creditService
        )
    }
}

@MainActor
private final class DetailMockCreditService: CreditServing {
    var balance: Int = 100
    var signInAvailable: Bool = false
    var currentSignInStreak: Int = 0

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

private struct MockCreditPreviewService: CreditPreviewServing {
    let preview: CreditPreview?
    let result: Result<CreditPreview, Error>?

    func preview(play: AIPlay, durationSeconds: Int?) async throws -> CreditPreview {
        if let result {
            return try result.get()
        }
        if let preview {
            return preview
        }
        return CreditPreview(costCredits: 0, balance: 0, signInAvailable: false)
    }
}

private struct MockAITaskSubmitService: AITaskSubmitting {
    let result: Result<AITaskCreatedData, Error>?

    func submit(
        play: AIPlay,
        context: AIPlaySubmissionContext,
        durationSeconds: Int?
    ) async throws -> AITaskCreatedData {
        if let result {
            return try result.get()
        }
        return AITaskCreatedData(
            taskId: "tsk_default",
            state: "credit_held",
            costCredits: 8,
            balanceAfter: 92
        )
    }
}
