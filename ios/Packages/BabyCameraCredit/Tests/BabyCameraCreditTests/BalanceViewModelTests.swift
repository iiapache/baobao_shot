import XCTest
@testable import BabyCameraCredit

@MainActor
final class BalanceViewModelTests: XCTestCase {
    func testReloadLoadsBalanceAndFirstPage() async {
        let mock = MockCreditService()
        mock.balanceResponse = 120
        mock.signInAvailableResponse = true
        mock.transactionPages = [
            CreditTransactionsPage(
                items: [
                    CreditTransaction(
                        id: "txn_001",
                        type: .grant,
                        amount: 20,
                        balanceAfter: 120,
                        createdAt: Date(timeIntervalSince1970: 1_000)
                    ),
                ],
                nextCursor: "cursor_2"
            ),
        ]

        let viewModel = BalanceViewModel(creditService: mock)
        await viewModel.reload()

        XCTAssertEqual(viewModel.balance, 120)
        XCTAssertTrue(viewModel.signInAvailable)
        XCTAssertEqual(viewModel.transactions.count, 1)
        XCTAssertTrue(viewModel.hasMore)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(mock.refreshBalanceCallCount, 1)
        XCTAssertEqual(mock.fetchTransactionsCallCount, 1)
    }

    func testLoadMoreAppendsTransactions() async {
        let mock = MockCreditService()
        mock.transactionPages = [
            CreditTransactionsPage(
                items: [
                    CreditTransaction(
                        id: "txn_001",
                        type: .consume,
                        amount: -8,
                        balanceAfter: 92,
                        createdAt: Date(timeIntervalSince1970: 1_000)
                    ),
                ],
                nextCursor: "cursor_2"
            ),
            CreditTransactionsPage(
                items: [
                    CreditTransaction(
                        id: "txn_002",
                        type: .refund,
                        amount: 8,
                        balanceAfter: 100,
                        createdAt: Date(timeIntervalSince1970: 2_000)
                    ),
                ],
                nextCursor: nil
            ),
        ]

        let viewModel = BalanceViewModel(creditService: mock)
        await viewModel.reload()
        await viewModel.loadMoreIfNeeded(currentItem: viewModel.transactions.first)

        XCTAssertEqual(viewModel.transactions.count, 2)
        XCTAssertFalse(viewModel.hasMore)
        XCTAssertEqual(mock.fetchTransactionsCallCount, 2)
    }

    func testReloadMapsNotAuthenticatedError() async {
        let mock = MockCreditService()
        mock.refreshBalanceError = CreditServiceError.notAuthenticated

        let viewModel = BalanceViewModel(creditService: mock)
        await viewModel.reload()

        XCTAssertEqual(viewModel.errorMessage, "请先登录")
        XCTAssertTrue(viewModel.transactions.isEmpty)
    }
}

@MainActor
private final class MockCreditService: CreditServing {
    var balance: Int = 0
    var signInAvailable: Bool = false
    var currentSignInStreak: Int = 0

    var balanceResponse = 0
    var signInAvailableResponse = false
    var signInResult: SignInResult?
    var signInError: Error?
    var transactionPages: [CreditTransactionsPage] = []
    var refreshBalanceError: Error?
    var fetchTransactionsError: Error?

    private(set) var refreshBalanceCallCount = 0
    private(set) var fetchTransactionsCallCount = 0
    private(set) var signInCallCount = 0
    private var nextPageIndex = 0

    func refreshBalance() async throws {
        refreshBalanceCallCount += 1
        if let refreshBalanceError {
            throw refreshBalanceError
        }
        balance = balanceResponse
        signInAvailable = signInAvailableResponse
    }

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
        fetchTransactionsCallCount += 1
        if let fetchTransactionsError {
            throw fetchTransactionsError
        }
        guard nextPageIndex < transactionPages.count else {
            return CreditTransactionsPage(items: [], nextCursor: nil)
        }
        defer { nextPageIndex += 1 }
        return transactionPages[nextPageIndex]
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
