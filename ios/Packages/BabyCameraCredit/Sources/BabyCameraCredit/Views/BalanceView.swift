import DesignSystem
import SwiftUI

public struct BalanceView: View {
    @ObservedObject private var viewModel: BalanceViewModel
    @ObservedObject private var creditService: CreditService

    private let iapService: IAPService?
    private let adManager: AdManager?
    private let onInviteFriends: () -> Void

    @State private var showRecharge = false

    public init(
        viewModel: BalanceViewModel,
        creditService: CreditService,
        iapService: IAPService? = nil,
        adManager: AdManager? = nil,
        onInviteFriends: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.creditService = creditService
        self.iapService = iapService
        self.adManager = adManager
        self.onInviteFriends = onInviteFriends
    }

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.transactions.isEmpty {
                DSLoadingView(message: "加载积分…")
            } else if viewModel.transactions.isEmpty, let errorMessage = viewModel.errorMessage {
                DSEmptyState(
                    systemImage: "creditcard.fill",
                    title: "加载失败",
                    message: errorMessage,
                    actionTitle: "重试"
                ) {
                    Task { await viewModel.reload() }
                }
            } else {
                content
            }
        }
        .navigationTitle("我的积分")
        .toolbar {
            if iapService != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("充值") { showRecharge = true }
                }
            }
        }
        .sheet(isPresented: $showRecharge) {
            if let iapService {
                RechargeSheet(
                    viewModel: RechargeViewModel(
                        iapService: iapService,
                        creditService: creditService
                    ),
                    onDismiss: { showRecharge = false }
                )
            }
        }
        .task {
            await viewModel.reload()
        }
    }

    private var content: some View {
        List {
            Section {
                balanceHeader
            }

            Section("获取积分") {
                NavigationLink {
                    SignInView(
                        viewModel: SignInViewModel(creditService: creditService),
                        onInviteFriends: onInviteFriends
                    )
                } label: {
                    earnCreditsRow(
                        title: "每日签到",
                        subtitle: signInSubtitle,
                        systemImage: "calendar.badge.checkmark",
                        highlight: creditService.signInAvailable
                    )
                }

                InviteRewardSection(onInvite: onInviteFriends)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                if iapService != nil {
                    Button {
                        showRecharge = true
                    } label: {
                        earnCreditsRow(
                            title: "充值积分",
                            subtitle: rechargeSubtitle,
                            systemImage: "creditcard.fill",
                            highlight: false
                        )
                    }
                    .buttonStyle(.plain)
                }

                if let adManager {
                    RewardedAdEntry(adManager: adManager) { _ in
                        Task { await viewModel.reload() }
                    }
                    .accessibilityIdentifier("balanceRewardedAdEntry")
                }
            }

            Section("流水记录") {
                if viewModel.transactions.isEmpty {
                    Text("暂无流水")
                        .font(DSTypography.body)
                        .foregroundStyle(DSColors.textSecondary)
                } else {
                    ForEach(viewModel.transactions) { transaction in
                        transactionRow(transaction)
                            .task {
                                await viewModel.loadMoreIfNeeded(currentItem: transaction)
                            }
                    }

                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.reload()
        }
    }

    private var signInSubtitle: String {
        if creditService.signInAvailable {
            return "今日可领 \(SignInCredits.minCredits)–\(SignInCredits.maxCredits) 积分"
        }
        if creditService.currentSignInStreak > 0 {
            return "已连续 \(creditService.currentSignInStreak) 天"
        }
        return "今日已签到"
    }

    private var rechargeSubtitle: String {
        let tiers = CreditIAPProductID.all.compactMap { CreditIAPProductID.creditsByProductID[$0] }
        guard let minCredits = tiers.min(), let maxCredits = tiers.max() else {
            return "苹果内购充值"
        }
        return "\(minCredits)–\(maxCredits) 积分档位"
    }

    private var balanceHeader: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("当前余额")
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)
            Text("\(creditService.balance)")
                .font(DSTypography.largeTitle)
                .foregroundStyle(DSColors.textPrimary)
                .accessibilityLabel("当前积分余额 \(creditService.balance)")
            if creditService.signInAvailable {
                Text("今日可签到领取积分")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DSSpacing.xs)
    }

    private func earnCreditsRow(
        title: String,
        subtitle: String,
        systemImage: String,
        highlight: Bool
    ) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(highlight ? DSColors.primary : DSColors.textSecondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(title)
                    .font(DSTypography.listTitle)
                    .foregroundStyle(DSColors.textPrimary)
                Text(subtitle)
                    .font(DSTypography.listSubtitle)
                    .foregroundStyle(highlight ? DSColors.primary : DSColors.textSecondary)
            }
        }
        .padding(.vertical, DSSpacing.xxs)
    }

    private func transactionRow(_ transaction: CreditTransaction) -> some View {
        HStack(spacing: DSSpacing.sm) {
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(transaction.title)
                    .font(DSTypography.listTitle)
                    .foregroundStyle(DSColors.textPrimary)
                Text(transaction.subtitle)
                    .font(DSTypography.listSubtitle)
                    .foregroundStyle(DSColors.textSecondary)
            }
            Spacer(minLength: DSSpacing.xs)
            Text(transaction.amountText)
                .font(DSTypography.listTitle.monospacedDigit())
                .foregroundStyle(transaction.amount >= 0 ? DSColors.success : DSColors.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(transaction.title)，\(transaction.amountText)，\(transaction.subtitle)")
    }
}
