import Foundation

@MainActor
public final class RechargeViewModel: ObservableObject {
    @Published public private(set) var products: [IAPProduct] = []
    @Published public private(set) var isLoadingProducts = false
    @Published public private(set) var purchasingProductID: String?
    @Published public private(set) var lastBalanceAfter: Int?
    @Published public var errorMessage: String?

    private let iapService: IAPService
    private weak var creditService: CreditService?

    public init(iapService: IAPService, creditService: CreditService? = nil) {
        self.iapService = iapService
        self.creditService = creditService
    }

    public func onAppear() {
        iapService.start()
        Task { await loadProducts() }
    }

    public func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            products = try await iapService.loadProducts()
        } catch {
            errorMessage = "无法加载充值档位，请稍后重试"
        }
    }

    public func purchase(product: IAPProduct) async {
        purchasingProductID = product.id
        defer { purchasingProductID = nil }

        do {
            let outcome = try await iapService.purchase(productID: product.id)
            lastBalanceAfter = outcome.verifyData.balanceAfter
            creditService?.applyBalance(outcome.verifyData.balanceAfter, channel: .rpc)
        } catch IAPServiceError.userCancelled {
            return
        } catch IAPServiceError.purchasePending {
            errorMessage = "购买待处理，请稍后在设置中确认"
        } catch {
            errorMessage = "购买失败，请稍后重试"
        }
    }
}
