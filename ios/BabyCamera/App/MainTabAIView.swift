import BabyCameraAccount
import BabyCameraAIPlay
import BabyCameraBaby
import BabyCameraCredit
import BabyCameraNetwork
import BabyCameraOnboarding
import BabyCameraSettings
import Database
import DesignSystem
import SwiftUI

/// AI Tab：玩法列表 → 详情提交 → 任务进度与结果下载（NAV-07）。
struct MainTabAIView: View {
    let session: AuthSession
    @EnvironmentObject private var coordinator: AccountCoordinator
    @ObservedObject var currentBabyStore: CurrentBabyEnvironment
    let appDatabase: AppDatabase

    @StateObject private var holder = MainTabAIHolder()
    @State private var selectedPlayId: String?
    @State private var detailViewModel: AIPlayDetailViewModel?
    @State private var progressRoute: AIProgressRoute?
    @State private var showBalance = false
    @State private var showSignIn = false
    @State private var iapService: IAPService?

    private var allowsAISubmit: Bool {
        session.allows(.aiSubmit)
    }

    var body: some View {
        NavigationStack {
            Group {
                if holder.isBootstrapping {
                    DSLoadingView(message: "加载 AI 玩法…", style: .fullScreen)
                } else if let errorMessage = holder.bootstrapError {
                    DSErrorView(
                        kind: DSUserFacingError.kind(for: holder.bootstrapErrorSource ?? NSError(domain: "", code: 0)),
                        title: "无法打开 AI 玩法",
                        message: errorMessage,
                        actionTitle: "重试"
                    ) {
                        Task { await bootstrap() }
                    }
                } else if let gridViewModel = holder.gridViewModel {
                    VStack(spacing: 0) {
                        AIPlayGridView(viewModel: gridViewModel) { play in
                            openDetail(for: play)
                        }
                        if let complianceService = holder.complianceService {
                            ComplianceFooterView(complianceService: complianceService, region: .cn)
                        }
                    }
                }
            }
            .navigationTitle("AI 玩法")
            .navigationDestination(item: $selectedPlayId) { playId in
                if let detailViewModel, detailViewModel.play.id == playId {
                    AIPlayDetailView(
                        viewModel: detailViewModel,
                        onRecharge: {
                            showBalance = true
                        },
                        onSignIn: {
                            showSignIn = true
                        },
                        onTaskSubmitted: { created in
                            handleTaskSubmitted(created, play: detailViewModel.play)
                        },
                        submitAllowed: allowsAISubmit,
                        restrictedSubmitContent: {
                            ConsentRestrictedView(feature: .aiSubmit)
                        }
                    )
                }
            }
            .navigationDestination(item: $progressRoute) { route in
                if let progressViewModel = holder.progressViewModel(for: route) {
                    AITaskProgressView(viewModel: progressViewModel) {
                        progressRoute = nil
                        selectedPlayId = nil
                        detailViewModel = nil
                    }
                }
            }
        }
        .accessibilityIdentifier("mainTabAIScreen")
        .sheet(isPresented: $showBalance) {
            if let creditService = holder.context?.creditService {
                NavigationStack {
                    BalanceView(
                        viewModel: BalanceViewModel(creditService: creditService),
                        creditService: creditService,
                        iapService: resolvedIAPService(),
                        onInviteFriends: {}
                    )
                    .navigationTitle("积分余额")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") { showBalance = false }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSignIn) {
            if let creditService = holder.context?.creditService {
                NavigationStack {
                    SignInView(
                        viewModel: SignInViewModel(creditService: creditService),
                        onInviteFriends: {}
                    )
                    .navigationTitle("每日签到")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") { showSignIn = false }
                        }
                    }
                }
            }
        }
        .task {
            await bootstrap()
        }
        .onChange(of: currentBabyStore.currentBabyId) { _ in
            Task { await bootstrap() }
        }
    }

    private func bootstrap() async {
        await holder.bootstrap(
            session: session,
            coordinator: coordinator,
            appDatabase: appDatabase,
            babyEnvironment: currentBabyStore
        )
        if iapService == nil {
            iapService = ProfileIntegrationContextFactory.make(
                accountCoordinator: coordinator,
                urlSession: UITestBootstrap.isEnabled ? MockURLProtocol.makeSession() : NetworkSessionFactory.makeSession()
            ).iapService
        }
    }

    private func resolvedIAPService() -> IAPService {
        iapService ?? ProfileIntegrationContextFactory.make(
            accountCoordinator: coordinator,
            urlSession: UITestBootstrap.isEnabled ? MockURLProtocol.makeSession() : NetworkSessionFactory.makeSession()
        ).iapService
    }

    private func openDetail(for play: AIPlay) {
        guard let context = holder.context else { return }
        let viewModel = AIPlayCreditIntegration.makeDetailViewModel(
            play: play,
            submissionContext: AIPlaySubmissionContext(
                inputObjectKey: context.inputObjectKey,
                familyId: context.familyId
            ),
            creditService: context.creditService,
            region: .cn,
            tokenStore: coordinator.authService.tokenStore,
            regionConfig: context.regionConfig,
            session: context.urlSession
        )
        detailViewModel = viewModel
        selectedPlayId = play.id
    }

    private func handleTaskSubmitted(_ created: AITaskCreatedData, play: AIPlay) {
        guard let context = holder.context else { return }

        Task {
            do {
                try await context.taskCoordinator.track(created: created)
                await context.downloadCoordinator.register(
                    taskId: created.taskId,
                    context: AITaskDownloadContext(
                        sourcePhotoId: context.sourcePhotoId,
                        babyId: context.currentBaby.id,
                        playKind: play.kind,
                        style: play.id,
                        costCredits: created.costCredits,
                        sourceUrl: context.sourcePhotoFilePath
                    )
                )
            } catch {
                return
            }

            await MainActor.run {
                holder.storeProgressViewModel(
                    route: AIProgressRoute(taskId: created.taskId, playName: play.name),
                    viewModel: AIPlayCreditIntegration.makeProgressViewModel(
                        created: created,
                        playName: play.name,
                        coordinator: context.taskCoordinator,
                        creditService: context.creditService,
                        tokenStore: coordinator.authService.tokenStore
                    )
                )
                progressRoute = AIProgressRoute(taskId: created.taskId, playName: play.name)
            }
        }
    }
}

private struct AIProgressRoute: Identifiable, Hashable {
    let taskId: String
    let playName: String

    var id: String { taskId }
}

@MainActor
private final class MainTabAIHolder: ObservableObject {
    @Published private(set) var isBootstrapping = false
    @Published private(set) var bootstrapError: String?
    @Published private(set) var bootstrapErrorSource: Error?
    @Published private(set) var context: AIIntegrationContext?
    @Published private(set) var gridViewModel: AIPlayGridViewModel?
    @Published private(set) var complianceService: (any ComplianceConfigServing)?

    private var progressViewModels: [String: AITaskProgressViewModel] = [:]

    func bootstrap(
        session: AuthSession,
        coordinator: AccountCoordinator,
        appDatabase: AppDatabase,
        babyEnvironment: CurrentBabyEnvironment
    ) async {
        guard !isBootstrapping else { return }
        isBootstrapping = true
        bootstrapError = nil
        bootstrapErrorSource = nil
        defer { isBootstrapping = false }

        let urlSession: URLSession = UITestBootstrap.isEnabled
            ? MockURLProtocol.makeSession()
            : NetworkSessionFactory.makeSession()

        do {
            let result = try await AIIntegrationContextFactory.bootstrap(
                session: session,
                accountCoordinator: coordinator,
                appDatabase: appDatabase,
                babyEnvironment: babyEnvironment,
                urlSession: urlSession
            )
            context = result.context
            gridViewModel = result.gridViewModel
            NotificationIntegrationBridge.register(taskCoordinator: result.context.taskCoordinator)
            complianceService = ComplianceConfigService(
                client: makeComplianceAPIClient(
                    session: session,
                    tokenStore: coordinator.authService.tokenStore,
                    urlSession: urlSession
                ),
                region: .cn
            )
        } catch {
            bootstrapErrorSource = error
            bootstrapError = DSUserFacingError.message(from: error, fallback: "无法打开 AI 玩法")
            NotificationIntegrationBridge.clear()
            context = nil
            gridViewModel = nil
            complianceService = nil
        }
    }

    func storeProgressViewModel(route: AIProgressRoute, viewModel: AITaskProgressViewModel) {
        progressViewModels[route.taskId] = viewModel
    }

    func progressViewModel(for route: AIProgressRoute) -> AITaskProgressViewModel? {
        progressViewModels[route.taskId]
    }

    private func makeComplianceAPIClient(
        session: AuthSession,
        tokenStore: TokenStore,
        urlSession: URLSession
    ) -> APIClient {
        let regionConfig = RegionConfig(
            region: .cn,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            deviceId: resolveDeviceId()
        )
        return APIClient(
            configuration: .standard(
                region: .cn,
                tokenStore: tokenStore,
                regionConfig: regionConfig
            ),
            session: urlSession
        )
    }

    private func resolveDeviceId() -> String {
        let key = "com.babycamera.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}
