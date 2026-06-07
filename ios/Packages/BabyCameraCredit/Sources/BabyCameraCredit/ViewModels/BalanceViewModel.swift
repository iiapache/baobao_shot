import BabyCameraNetwork
import Foundation

@MainActor
public final class BalanceViewModel: ObservableObject {
    @Published public private(set) var transactions: [CreditTransaction] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isLoadingMore = false
    @Published public private(set) var hasMore = true
    @Published public private(set) var errorMessage: String?

    public let creditService: any CreditServing

    private var nextCursor: String?

    public init(creditService: any CreditServing) {
        self.creditService = creditService
    }

    public var balance: Int {
        creditService.balance
    }

    public var signInAvailable: Bool {
        creditService.signInAvailable
    }

    public func reload() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await creditService.refreshBalance()
            let page = try await creditService.fetchTransactions(cursor: nil)
            transactions = page.items
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
        } catch {
            errorMessage = mapError(error)
        }
    }

    public func loadMoreIfNeeded(currentItem: CreditTransaction?) async {
        guard let currentItem,
              let index = transactions.firstIndex(where: { $0.id == currentItem.id }),
              index >= transactions.count - 3,
              hasMore,
              !isLoadingMore,
              !isLoading
        else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await creditService.fetchTransactions(cursor: nextCursor)
            guard !page.items.isEmpty else {
                hasMore = false
                nextCursor = nil
                return
            }
            transactions.append(contentsOf: page.items)
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
        } catch {
            errorMessage = mapError(error)
        }
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        if let creditError = error as? CreditServiceError {
            switch creditError {
            case .notAuthenticated:
                return "请先登录"
            }
        }
        return "加载失败，请稍后重试"
    }
}
