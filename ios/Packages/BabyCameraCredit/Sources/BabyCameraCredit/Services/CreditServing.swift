import Foundation

public enum CreditServiceError: Error, Equatable, Sendable {
    case notAuthenticated
}

public protocol CreditServing: AnyObject {
    var balance: Int { get }
    var signInAvailable: Bool { get }
    var currentSignInStreak: Int { get }

    func refreshBalance() async throws
    func signIn() async throws -> SignInResult
    func fetchTransactions(cursor: String?, limit: Int) async throws -> CreditTransactionsPage
    func bindWebSocketEvents(_ events: AsyncStream<AITaskBalanceEvent>)
    func unbindWebSocketEvents()
    /// AI 任务预扣 / 退还后同步余额（WebSocket 或提交响应）。
    func applyBalanceFromAITask(_ balanceAfter: Int)
    /// 提交前预览：远端单价 + 当前余额。
    func previewCost(playId: String, durationSeconds: Int?, localCost: Int) async throws -> CreditCostPreview
}

public struct AITaskBalanceEvent: Sendable, Equatable {
    public let taskId: String
    public let balanceAfter: Int

    public init(taskId: String, balanceAfter: Int) {
        self.taskId = taskId
        self.balanceAfter = balanceAfter
    }
}
