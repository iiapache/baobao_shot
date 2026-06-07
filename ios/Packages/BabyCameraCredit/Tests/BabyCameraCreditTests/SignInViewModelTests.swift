import BabyCameraNetwork
import XCTest
@testable import BabyCameraCredit

@MainActor
final class SignInViewModelTests: XCTestCase {
    func testSignInSuccessUpdatesPhase() async {
        let mock = MockSignInCreditService()
        mock.signInAvailable = true
        mock.signInResult = SignInResult(
            grantedCredits: 6,
            balanceAfter: 106,
            streak: 2,
            ledgerId: "led_001"
        )

        let viewModel = SignInViewModel(creditService: mock)
        await viewModel.signIn()

        XCTAssertEqual(viewModel.phase, .completed(mock.signInResult!))
        XCTAssertEqual(viewModel.currentStreak, 2)
        XCTAssertFalse(viewModel.signInAvailable)
        XCTAssertEqual(mock.signInCallCount, 1)
    }

    func testSignInMapsAlreadyDoneError() async {
        let mock = MockSignInCreditService()
        mock.signInAvailable = true
        mock.signInError = APIError(
            code: .creditSignInDone,
            message: "already signed in today",
            httpStatusCode: 409,
            requestId: "req_dup"
        )

        let viewModel = SignInViewModel(creditService: mock)
        await viewModel.signIn()

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertEqual(viewModel.errorMessage, "今日已签到")
    }

    func testTodayCreditsHintWhenAvailable() {
        let mock = MockSignInCreditService()
        mock.signInAvailable = true
        mock.currentSignInStreak = 3

        let viewModel = SignInViewModel(creditService: mock)
        XCTAssertTrue(viewModel.todayCreditsHint.contains("明日预计 8 积分"))
    }
}

@MainActor
private final class MockSignInCreditService: CreditServing {
    var balance: Int = 0
    var signInAvailable: Bool = false
    var currentSignInStreak: Int = 0

    var signInResult: SignInResult?
    var signInError: Error?

    private(set) var signInCallCount = 0

    func refreshBalance() async throws {}

    func signIn() async throws -> SignInResult {
        signInCallCount += 1
        if let signInError {
            throw signInError
        }
        guard let signInResult else {
            throw CreditServiceError.notAuthenticated
        }
        balance = signInResult.balanceAfter
        signInAvailable = false
        currentSignInStreak = signInResult.streak
        return signInResult
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
