import DesignSystem
import SwiftUI

public struct RechargeSheet: View {
    @ObservedObject private var viewModel: RechargeViewModel
    private let onDismiss: () -> Void

    public init(viewModel: RechargeViewModel, onDismiss: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingProducts && viewModel.products.isEmpty {
                    ProgressView("加载充值档位…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    productList
                }
            }
            .background(DSColors.background)
            .navigationTitle("充值积分")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { onDismiss() }
                }
            }
            .onAppear { viewModel.onAppear() }
            .alert("提示", isPresented: errorBinding) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("充值成功", isPresented: successBinding) {
                Button("好的", role: .cancel) {
                    viewModel.lastBalanceAfter = nil
                }
            } message: {
                if let balance = viewModel.lastBalanceAfter {
                    Text("当前余额 \(balance) 积分")
                }
            }
        }
    }

    private var productList: some View {
        List(viewModel.products) { product in
            Button {
                Task { await viewModel.purchase(product: product) }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        HStack(spacing: DSSpacing.xs) {
                            Text("\(product.credits) 积分")
                                .font(DSTypography.headline)
                                .foregroundStyle(DSColors.textPrimary)
                            if let tierName = product.tierName {
                                Text(tierName)
                                    .font(DSTypography.caption)
                                    .foregroundStyle(DSColors.primary)
                                    .padding(.horizontal, DSSpacing.xs)
                                    .padding(.vertical, 2)
                                    .background(DSColors.primary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(product.displayName)
                            .font(DSTypography.caption)
                            .foregroundStyle(DSColors.textSecondary)
                    }
                    Spacer()
                    if viewModel.purchasingProductID == product.id {
                        ProgressView()
                    } else {
                        Text(product.displayPrice)
                            .font(DSTypography.headline)
                            .foregroundStyle(DSColors.primary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.purchasingProductID != nil)
        }
        .listStyle(.insetGrouped)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    private var successBinding: Binding<Bool> {
        Binding(
            get: { viewModel.lastBalanceAfter != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.lastBalanceAfter = nil
                }
            }
        )
    }
}
