import BabyCameraAccount
import BabyCameraBaby
import BabyCameraFamilyFeed
import BabyCameraNetwork
import BabyCameraOnboarding
import Database
import DesignSystem
import SwiftUI

/// 家庭圈 Tab：FeedListView + PostComposerView（NAV-06）。
struct MainTabFeedView: View {
    let session: AuthSession
    @EnvironmentObject private var coordinator: AccountCoordinator
    @ObservedObject var currentBabyStore: CurrentBabyEnvironment
    let appDatabase: AppDatabase

    @StateObject private var holder = MainTabFeedHolder()
    @State private var showComposer = false
    @State private var composerViewModel: PostComposerViewModel?
    @State private var blockedEngagementFeature: RestrictedFeature?

    private var allowsFeedPublish: Bool {
        session.allows(.feedPublish)
    }

    private var allowsFeedEngagement: Bool {
        session.allows(.feedEngagement)
    }

    var body: some View {
        NavigationStack {
            Group {
                if holder.isBootstrapping {
                    DSLoadingView(message: "加载家庭圈…", style: .fullScreen)
                } else if let errorMessage = holder.bootstrapError {
                    DSErrorView(
                        kind: DSUserFacingError.kind(for: holder.bootstrapErrorSource ?? NSError(domain: "", code: 0)),
                        title: "无法打开家庭圈",
                        message: errorMessage,
                        actionTitle: "重试"
                    ) {
                        Task { await bootstrap() }
                    }
                } else if let feedListVM = holder.feedCoordinator?.feedListViewModel,
                          let babyEnvironment = holder.babyEnvironment {
                    FeedListView(
                        viewModel: feedListVM,
                        currentBabyEnvironment: babyEnvironment,
                        isEngagementAllowed: allowsFeedEngagement,
                        onEngagementBlocked: {
                            blockedEngagementFeature = .feedEngagement
                        }
                    )
                }
            }
            .navigationTitle("家庭圈")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openComposer()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(DSColors.primary)
                    }
                    .accessibilityLabel("发布动态")
                    .accessibilityIdentifier("feedComposeButton")
                    .disabled(holder.feedCoordinator == nil)
                }
            }
            .navigationDestination(isPresented: $showComposer) {
                if allowsFeedPublish,
                   let composerViewModel,
                   let feedCoordinator = holder.feedCoordinator,
                   let context = holder.context {
                    PostComposerView(
                        viewModel: composerViewModel,
                        onBeforePublish: { composer in
                            try await FeedPostPublishHelper.ensureMediaReady(
                                composer: composer,
                                client: makePublishClient(),
                                familyId: context.familyId,
                                useMockShortcuts: UITestBootstrap.isEnabled
                            )
                        }
                    )
                    .onChange(of: composerViewModel.phase) { _, phase in
                        if case .published = phase {
                            Task {
                                await feedCoordinator.feedListViewModel?.reload()
                            }
                        }
                    }
                } else {
                    ConsentRestrictedView(feature: .feedPublish)
                        .navigationTitle("发布动态")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .accessibilityIdentifier("mainTabFeedScreen")
        .sheet(item: $blockedEngagementFeature) { feature in
            NavigationStack {
                ConsentRestrictedView(feature: feature)
                    .navigationTitle("互动")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") {
                                blockedEngagementFeature = nil
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            await bootstrap()
        }
        .onChange(of: currentBabyStore.currentBabyId) { _ in
            holder.syncCurrentBaby(from: currentBabyStore)
        }
    }

    private func bootstrap() async {
        await holder.bootstrap(
            session: session,
            coordinator: coordinator,
            appDatabase: appDatabase,
            babyEnvironment: currentBabyStore
        )
    }

    private func openComposer() {
        guard holder.context != nil, holder.currentBaby != nil else { return }

        if allowsFeedPublish,
           let context = holder.context,
           let baby = holder.currentBaby {
            composerViewModel = FamilyFeedIntegration.makePostComposerViewModel(
                context: context,
                baby: baby
            )
        } else {
            composerViewModel = nil
        }
        showComposer = true
    }

    private func makePublishClient() -> APIClient {
        let tokenStore = coordinator.authService.tokenStore
        let regionConfig = RegionConfig(
            region: .cn,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            deviceId: UserDefaults.standard.string(forKey: "com.babycamera.deviceId") ?? "device-unknown"
        )
        let session: URLSession = UITestBootstrap.isEnabled
            ? MockURLProtocol.makeSession()
            : NetworkSessionFactory.makeSession()
        return makeAuthenticatedClient(
            region: .cn,
            tokenStore: tokenStore,
            regionConfig: regionConfig,
            session: session
        )
    }
}

@MainActor
private final class MainTabFeedHolder: ObservableObject {
    @Published private(set) var isBootstrapping = false
    @Published private(set) var bootstrapError: String?
    @Published private(set) var bootstrapErrorSource: Error?
    @Published private(set) var context: FeedIntegrationContext?
    @Published private(set) var babyEnvironment: CurrentBabyEnvironment?
    @Published private(set) var currentBaby: BabyProfile?
    @Published private(set) var feedCoordinator: FeedCoordinator?

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
            let result = try await FeedIntegrationContextFactory.bootstrap(
                session: session,
                accountCoordinator: coordinator,
                appDatabase: appDatabase,
                babyEnvironment: babyEnvironment,
                urlSession: urlSession
            )
            context = result.context
            babyEnvironment = result.babyEnvironment
            currentBaby = result.currentBaby
            feedCoordinator = result.feedCoordinator
        } catch {
            bootstrapErrorSource = error
            bootstrapError = DSUserFacingError.message(from: error, fallback: "无法打开家庭圈")
        }
    }

    func syncCurrentBaby(from environment: CurrentBabyEnvironment) {
        currentBaby = environment.currentBaby
    }
}
