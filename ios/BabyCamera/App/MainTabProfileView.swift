import BabyCameraAccount
import BabyCameraCredit
import BabyCameraNetwork
import BabyCameraSettings
import Database
import DesignSystem
import SwiftUI

/// 「我的」Tab：积分余额、订阅、签到与设置入口（NAV-08）。
struct MainTabProfileView: View {
    let session: AuthSession
    @EnvironmentObject private var coordinator: AccountCoordinator
    let appDatabase: AppDatabase

    @StateObject private var holder = MainTabProfileHolder()

    var body: some View {
        NavigationStack {
            Group {
                if let creditService = holder.creditService,
                   let subscriptionStore = holder.subscriptionStore,
                   let iapService = holder.iapService,
                   let adManager = holder.adManager {
                    profileList(
                        creditService: creditService,
                        subscriptionStore: subscriptionStore,
                        iapService: iapService,
                        adManager: adManager
                    )
                } else if let bootstrapError = holder.bootstrapError {
                    DSErrorView(
                        kind: .generic,
                        title: "无法加载账户信息",
                        message: bootstrapError,
                        actionTitle: "重试"
                    ) {
                        Task {
                            holder.bootstrap(coordinator: coordinator)
                            await holder.refresh()
                        }
                    }
                } else {
                    DSLoadingView(message: "加载账户信息…", style: .fullScreen)
                }
            }
            .navigationTitle("我的")
            .task {
                holder.bootstrap(coordinator: coordinator)
                await holder.refresh()
            }
            .refreshable {
                await holder.refresh()
            }
        }
        .accessibilityIdentifier("mainTabProfileScreen")
    }

    @ViewBuilder
    private func profileList(
        creditService: CreditService,
        subscriptionStore: SubscriptionStore,
        iapService: IAPService,
        adManager: AdManager
    ) -> some View {
        List {
            if let loadError = holder.loadError {
                Section {
                    DSErrorView(
                        kind: .network,
                        message: loadError,
                        actionTitle: "重新同步",
                        style: .banner
                    ) {
                        Task { await holder.refresh() }
                    }
                    .listRowInsets(EdgeInsets(top: DSSpacing.xs, leading: DSSpacing.md, bottom: DSSpacing.xs, trailing: DSSpacing.md))
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                profileHeader
                creditSummaryRow(
                    creditService: creditService,
                    iapService: iapService,
                    adManager: adManager
                )
            }

            Section("会员与积分") {
                NavigationLink {
                    SignInView(
                        viewModel: SignInViewModel(creditService: creditService),
                        onInviteFriends: {}
                    )
                } label: {
                    signInRow(creditService: creditService)
                }
                .accessibilityIdentifier("profileSignInLink")

                NavigationLink {
                    SubscriptionView(store: subscriptionStore)
                } label: {
                    subscriptionRow(subscriptionStore: subscriptionStore)
                }
                .accessibilityIdentifier("profileSubscriptionLink")
            }

            Section("设置") {
                NavigationLink {
                    SettingsRootView(
                        context: SettingsIntegrationContextFactory.make(
                            session: session,
                            accountCoordinator: coordinator,
                            appDatabase: appDatabase,
                            forceStubBackupOAuth: UITestBootstrap.isEnabled
                        )
                    )
                } label: {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .accessibilityIdentifier("settingsRootLink")

                NavigationLink {
                    AccountSettingsView(coordinator: coordinator)
                } label: {
                    Label("账号设置", systemImage: "person.crop.circle")
                }
                .accessibilityIdentifier("accountSettingsLink")
            }

            Section("开发") {
                NavigationLink {
                    DesignSystemCatalogView()
                } label: {
                    Label("Design System Catalog", systemImage: "paintpalette.fill")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var profileHeader: some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(DSColors.primary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(session.profile?.nickname ?? "欢迎回来")
                    .font(DSTypography.title3)
                    .foregroundStyle(DSColors.textPrimary)
                    .accessibilityIdentifier("homeWelcomeLabel")

                if holder.isRefreshing {
                    Text("同步中…")
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.textSecondary)
                }
            }
        }
        .padding(.vertical, DSSpacing.xxs)
    }

    private func creditSummaryRow(
        creditService: CreditService,
        iapService: IAPService,
        adManager: AdManager
    ) -> some View {
        NavigationLink {
            BalanceView(
                viewModel: BalanceViewModel(creditService: creditService),
                creditService: creditService,
                iapService: iapService,
                adManager: adManager,
                onInviteFriends: {}
            )
        } label: {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: "creditcard.fill")
                    .font(.title3)
                    .foregroundStyle(DSColors.primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text("积分余额")
                        .font(DSTypography.listTitle)
                        .foregroundStyle(DSColors.textPrimary)
                    Text(creditSubtitle(creditService: creditService))
                        .font(DSTypography.listSubtitle)
                        .foregroundStyle(
                            creditService.signInAvailable ? DSColors.primary : DSColors.textSecondary
                        )
                }

                Spacer(minLength: DSSpacing.xs)

                Text("\(creditService.balance)")
                    .font(DSTypography.title3.monospacedDigit())
                    .foregroundStyle(DSColors.textPrimary)
                    .accessibilityIdentifier("profileCreditBalance")
            }
            .padding(.vertical, DSSpacing.xxs)
        }
        .accessibilityIdentifier("profileCreditsLink")
    }

    private func creditSubtitle(creditService: CreditService) -> String {
        if creditService.signInAvailable {
            return "今日可签到领取积分"
        }
        if creditService.currentSignInStreak > 0 {
            return "已连续签到 \(creditService.currentSignInStreak) 天"
        }
        return "查看流水与充值"
    }

    private func signInRow(creditService: CreditService) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title3)
                .foregroundStyle(creditService.signInAvailable ? DSColors.primary : DSColors.textSecondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text("每日签到")
                    .font(DSTypography.listTitle)
                    .foregroundStyle(DSColors.textPrimary)
                Text(signInSubtitle(creditService: creditService))
                    .font(DSTypography.listSubtitle)
                    .foregroundStyle(
                        creditService.signInAvailable ? DSColors.primary : DSColors.textSecondary
                    )
            }
        }
        .padding(.vertical, DSSpacing.xxs)
    }

    private func signInSubtitle(creditService: CreditService) -> String {
        if creditService.signInAvailable {
            return "今日可领 \(SignInCredits.minCredits)–\(SignInCredits.maxCredits) 积分"
        }
        if creditService.currentSignInStreak > 0 {
            return "已连续 \(creditService.currentSignInStreak) 天"
        }
        return "今日已签到"
    }

    private func subscriptionRow(subscriptionStore: SubscriptionStore) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "crown.fill")
                .font(.title3)
                .foregroundStyle(subscriptionStore.isEntitled ? DSColors.primary : DSColors.textSecondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text("会员订阅")
                    .font(DSTypography.listTitle)
                    .foregroundStyle(DSColors.textPrimary)
                Text(subscriptionSubtitle(subscriptionStore: subscriptionStore))
                    .font(DSTypography.listSubtitle)
                    .foregroundStyle(DSColors.textSecondary)
            }
        }
        .padding(.vertical, DSSpacing.xxs)
    }

    private func subscriptionSubtitle(subscriptionStore: SubscriptionStore) -> String {
        if subscriptionStore.isEntitled {
            if let periodEnd = subscriptionStore.periodEnd {
                return "会员有效 · 至 \(periodEnd)"
            }
            return "会员有效"
        }
        switch subscriptionStore.state {
        case .expired:
            return "订阅已过期"
        case .grace:
            return "宽限期，请检查续费"
        default:
            return "开通后可去广告并关闭品牌水印"
        }
    }
}

@MainActor
private final class MainTabProfileHolder: ObservableObject {
    @Published private(set) var bootstrapError: String?
    @Published private(set) var creditService: CreditService?
    @Published private(set) var subscriptionStore: SubscriptionStore?
    @Published private(set) var iapService: IAPService?
    @Published private(set) var adManager: AdManager?
    @Published private(set) var isRefreshing = false
    @Published private(set) var loadError: String?

    func bootstrap(coordinator: AccountCoordinator) {
        guard creditService == nil else { return }

        bootstrapError = nil

        let urlSession: URLSession = UITestBootstrap.isEnabled
            ? MockURLProtocol.makeSession()
            : NetworkSessionFactory.makeSession()

        let services = ProfileIntegrationContextFactory.make(
            accountCoordinator: coordinator,
            urlSession: urlSession
        )
        creditService = services.creditService
        subscriptionStore = services.subscriptionStore
        iapService = services.iapService
        adManager = services.adManager

        if creditService == nil || subscriptionStore == nil || iapService == nil || adManager == nil {
            bootstrapError = "账户服务初始化失败"
        }
    }

    func refresh() async {
        guard let creditService, let subscriptionStore else { return }
        guard !isRefreshing else { return }

        isRefreshing = true
        loadError = nil
        defer { isRefreshing = false }

        var errors: [String] = []

        do {
            try await creditService.refreshBalance()
        } catch {
            errors.append("积分同步失败")
        }

        do {
            try await subscriptionStore.refreshIfNeeded()
        } catch {
            errors.append("订阅状态同步失败")
        }

        loadError = errors.isEmpty ? nil : errors.joined(separator: " · ")
    }
}
