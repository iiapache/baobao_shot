import DesignSystem
import SwiftUI

public struct SubscriptionView: View {
    @ObservedObject private var store: SubscriptionStore
    @State private var products: [SubscriptionListedProduct] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var purchasingProductID: String?

    public init(store: SubscriptionStore) {
        self.store = store
    }

    public var body: some View {
        Group {
            if isLoading, products.isEmpty {
                DSLoadingView(message: "加载订阅…")
            } else if let errorMessage, products.isEmpty {
                DSEmptyState(
                    systemImage: "crown.fill",
                    title: "加载失败",
                    message: errorMessage,
                    actionTitle: "重试"
                ) {
                    Task { await reload() }
                }
            } else {
                content
            }
        }
        .navigationTitle("会员订阅")
        .task {
            await reload()
        }
    }

    private var content: some View {
        List {
            Section {
                statusHeader
            }

            if store.isEntitled, store.entitlements.brandWatermarkRemovable {
                Section("权益设置") {
                    Toggle("显示品牌水印", isOn: brandWatermarkBinding)
                }
            }

            Section("订阅方案") {
                if products.isEmpty {
                    Text("暂无可用方案")
                        .foregroundStyle(DSColors.textSecondary)
                } else {
                    ForEach(products) { product in
                        productRow(product)
                    }
                }
            }
        }
    }

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.isEntitled ? "会员有效" : "未开通会员")
                .font(DSTypography.title3)
                .foregroundStyle(DSColors.textPrimary)

            Text(statusDetail)
                .font(DSTypography.body)
                .foregroundStyle(DSColors.textSecondary)

            if store.isEntitled {
                Label(
                    store.shouldShowAds ? "广告仍展示（权益异常）" : "已去广告",
                    systemImage: store.shouldShowAds ? "exclamationmark.triangle" : "checkmark.circle.fill"
                )
                .font(DSTypography.caption)
                .foregroundStyle(store.shouldShowAds ? DSColors.warning : DSColors.success)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusDetail: String {
        switch store.state {
        case .trial:
            return "试用中"
        case .active:
            if let periodEnd = store.periodEnd {
                return "有效期至 \(periodEnd)"
            }
            return "订阅生效中"
        case .grace:
            return "宽限期，请检查续费"
        case .expired:
            return "订阅已过期"
        case .refunded:
            return "订阅已退款"
        case .none:
            return "开通后可去广告并关闭品牌水印"
        }
    }

    private func productRow(_ product: SubscriptionListedProduct) -> some View {
        Button {
            Task { await purchase(product) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(DSTypography.body)
                        .foregroundStyle(DSColors.textPrimary)
                    if let bonus = product.bonusCredits, bonus > 0 {
                        Text("赠 \(bonus) 积分")
                            .font(DSTypography.caption)
                            .foregroundStyle(DSColors.textSecondary)
                    }
                }
                Spacer()
                if purchasingProductID == product.productId {
                    ProgressView()
                } else if let price = product.priceCny, price > 0 {
                    Text("¥\(price)")
                        .font(DSTypography.body)
                        .foregroundStyle(DSColors.primary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(purchasingProductID != nil || store.isEntitled)
    }

    private func purchase(_ product: SubscriptionListedProduct) async {
        purchasingProductID = product.productId
        defer { purchasingProductID = nil }

        do {
            _ = try await store.purchase(productID: product.productId)
        } catch IAPServiceError.userCancelled {
            return
        } catch {
            errorMessage = mapPurchaseError(error)
        }
    }

    private var brandWatermarkBinding: Binding<Bool> {
        Binding(
            get: { store.brandWatermarkVisible },
            set: { store.setBrandWatermarkVisible($0) }
        )
    }

    private func reload() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await store.refreshIfNeeded()
            products = try await store.fetchProducts()
        } catch {
            errorMessage = mapError(error)
        }
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        if let storeError = error as? SubscriptionStoreError {
            switch storeError {
            case .notAuthenticated:
                return "请先登录"
            case .verifyFailed, .nonRetriableVerifyFailure:
                return "订阅校验失败"
            }
        }
        return "加载失败，请稍后重试"
    }

    private func mapPurchaseError(_ error: Error) -> String {
        if let iapError = error as? IAPServiceError {
            switch iapError {
            case .userCancelled:
                return ""
            case .purchasePending:
                return "购买待处理，请稍后在设置中确认"
            case .productNotFound:
                return "商品不可用"
            default:
                return "购买失败，请稍后重试"
            }
        }
        if let storeError = error as? SubscriptionStoreError {
            switch storeError {
            case .notAuthenticated:
                return "请先登录"
            case .verifyFailed, .nonRetriableVerifyFailure:
                return "订阅校验失败"
            }
        }
        return mapError(error)
    }
}
