import BabyCameraAccount
import BabyCameraBaby
import BabyCameraEditor
import BabyCameraMilestone
import BabyCameraNetwork
import BabyCameraSettings
import BabyCameraTimeline
import Database
import DesignSystem
import SwiftUI

/// 主 App Tab 壳：相机 / 成长 / 家庭圈 / AI / 我的。
/// NAV-02~08 将逐 Tab 替换占位内容为真实模块。
struct MainTabShellView: View {
    let session: AuthSession
    @EnvironmentObject private var coordinator: AccountCoordinator
    @EnvironmentObject private var currentBabyStore: CurrentBabyEnvironment
    @StateObject private var shellState: MainTabShellState
    @StateObject private var editorFlowStore: MainTabEditorFlowStore
    @StateObject private var networkReachability = NetworkReachability()
    @State private var selectedTab: MainTab = .camera
    @State private var timelineReloadToken = UUID()
    @State private var showAddBabySheet = false

    init(session: AuthSession) {
        self.session = session
        let database = MainTabShellState.makeDatabase()
        _shellState = StateObject(wrappedValue: MainTabShellState(database: database))
        _editorFlowStore = StateObject(wrappedValue: MainTabEditorFlowStore(appDatabase: database))
    }

    var body: some View {
        VStack(spacing: 0) {
            MainTabBabySwitcherHeader(
                currentBabyStore: currentBabyStore,
                onAddBaby: { showAddBabySheet = true },
                onSelectBaby: { _ in
                    timelineReloadToken = UUID()
                }
            )

            tabContent
        }
        .environmentObject(networkReachability)
        .onAppear {
            networkReachability.start()
        }
        .onDisappear {
            networkReachability.stop()
        }
        .task {
            await MainTabBabyLoader.load(into: currentBabyStore, database: shellState.appDatabase)
        }
        .sheet(isPresented: $showAddBabySheet) {
            MainTabAddBabyView(
                session: session,
                appDatabase: shellState.appDatabase,
                currentBabyStore: currentBabyStore
            )
        }
    }

    private var tabContent: some View {
        TabView(selection: $selectedTab) {
            MainTabCameraView(
                session: session,
                appDatabase: shellState.appDatabase,
                babyStore: currentBabyStore,
                onPhotoCaptured: { photoId in
                    editorFlowStore.presentEditor(photoId: photoId, isReEdit: false)
                }
            )
                .tabItem {
                    Label(MainTab.camera.title, systemImage: MainTab.camera.icon)
                }
                .tag(MainTab.camera)
                .accessibilityIdentifier("mainTabCamera")

            MainTabGrowthView(
                appDatabase: shellState.appDatabase,
                currentBabyStore: currentBabyStore,
                isSelected: selectedTab == .growth,
                reloadToken: timelineReloadToken,
                onPhotoTap: { item in
                    editorFlowStore.presentEditor(photoId: item.id, isReEdit: true)
                }
            )
            .tabItem {
                Label(MainTab.growth.title, systemImage: MainTab.growth.icon)
            }
            .tag(MainTab.growth)
            .accessibilityIdentifier("mainTabGrowth")

            MainTabFeedView(
                session: session,
                currentBabyStore: currentBabyStore,
                appDatabase: shellState.appDatabase
            )
            .tabItem {
                Label(MainTab.feed.title, systemImage: MainTab.feed.icon)
            }
            .tag(MainTab.feed)
            .accessibilityIdentifier("mainTabFeed")

            MainTabAIView(
                session: session,
                currentBabyStore: currentBabyStore,
                appDatabase: shellState.appDatabase
            )
            .tabItem {
                Label(MainTab.ai.title, systemImage: MainTab.ai.icon)
            }
            .tag(MainTab.ai)
            .accessibilityIdentifier("mainTabAI")

            MainTabProfileView(
                session: session,
                appDatabase: shellState.appDatabase
            )
            .tabItem {
                Label(MainTab.profile.title, systemImage: MainTab.profile.icon)
            }
            .tag(MainTab.profile)
            .accessibilityIdentifier("mainTabProfile")
        }
        .tint(DSColors.primary)
        .accessibilityIdentifier("mainHomeView")
        .onAppear {
            editorFlowStore.onEditorDidSave = {
                selectedTab = .growth
                timelineReloadToken = UUID()
            }
        }
        .fullScreenCover(item: $editorFlowStore.activeSession) { session in
            NavigationStack {
                PhotoEditorFlowView(
                    store: editorFlowStore,
                    photoId: session.photoId,
                    isReEdit: session.isReEdit
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            editorFlowStore.dismissEditor()
                        }
                        .accessibilityIdentifier("editorCancelButton")
                    }
                }
            }
            .accessibilityIdentifier("mainTabEditorScreen")
        }
    }
}

// MARK: - Baby Switcher Header

/// 各 Tab 共享顶栏：横向滚动切换当前宝宝（NAV-09）。
private struct MainTabBabySwitcherHeader: View {
    @ObservedObject var currentBabyStore: CurrentBabyEnvironment
    let onAddBaby: () -> Void
    let onSelectBaby: (BabyProfile) -> Void

    var body: some View {
        BabySwitcherView(
            currentBabyStore: currentBabyStore,
            onAddBaby: onAddBaby,
            onSelectBaby: onSelectBaby
        )
        .background(DSColors.surface)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityIdentifier("mainTabBabySwitcherHeader")
    }
}

// MARK: - Tab Definition

private enum MainTab: Hashable {
    case camera
    case growth
    case feed
    case ai
    case profile

    var title: String {
        switch self {
        case .camera: return "相机"
        case .growth: return "成长"
        case .feed: return "家庭圈"
        case .ai: return "AI"
        case .profile: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .camera: return "camera.fill"
        case .growth: return "calendar"
        case .feed: return "person.3.fill"
        case .ai: return "sparkles"
        case .profile: return "person.crop.circle.fill"
        }
    }
}

// MARK: - Placeholder Tabs

/// 成长 Tab：本地 photo 表 + `GrowthTimelineView`（日/月/年/地图）。
private struct MainTabGrowthView: View {
    let appDatabase: AppDatabase
    @ObservedObject var currentBabyStore: CurrentBabyEnvironment
    let isSelected: Bool
    let reloadToken: UUID
    let onPhotoTap: (TimelinePhotoItem) -> Void

    @StateObject private var timelineViewModel: TimelineViewModel
    @State private var showMilestones = false

    init(
        appDatabase: AppDatabase,
        currentBabyStore: CurrentBabyEnvironment,
        isSelected: Bool,
        reloadToken: UUID = UUID(),
        onPhotoTap: @escaping (TimelinePhotoItem) -> Void
    ) {
        self.appDatabase = appDatabase
        self.currentBabyStore = currentBabyStore
        self.isSelected = isSelected
        self.reloadToken = reloadToken
        self.onPhotoTap = onPhotoTap
        _timelineViewModel = StateObject(wrappedValue: TimelineViewModel(
            photoSource: PhotoRepositoryTimelineSource(
                repository: appDatabase.makePhotoRepository()
            ),
            currentBabyStore: currentBabyStore,
            initialScale: .day
        ))
    }

    var body: some View {
        NavigationStack {
            GrowthTimelineView(
                viewModel: timelineViewModel,
                onPhotoTap: onPhotoTap
            )
            .navigationTitle("成长")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMilestones = true
                    } label: {
                        Label("里程碑", systemImage: "flag.fill")
                            .foregroundStyle(DSColors.primary)
                    }
                    .accessibilityLabel("里程碑")
                    .accessibilityIdentifier("growthMilestoneEntry")
                }
            }
            .navigationDestination(isPresented: $showMilestones) {
                MainTabMilestoneView(
                    appDatabase: appDatabase,
                    currentBabyStore: currentBabyStore
                )
            }
        }
        .accessibilityIdentifier("mainTabGrowthScreen")
        .task(id: isSelected) {
            guard isSelected else { return }
            await syncCurrentBabyFromDatabase()
            await timelineViewModel.reload()
        }
        .task(id: reloadToken) {
            await timelineViewModel.reload()
        }
        .onChange(of: currentBabyStore.currentBabyId) { _ in
            Task { await timelineViewModel.reload() }
        }
    }

    private func syncCurrentBabyFromDatabase() async {
        guard currentBabyStore.babies.isEmpty else { return }
        let repository = appDatabase.makeBabyRepository()
        if let babyId = currentBabyStore.currentBabyId,
           let record = try? await repository.fetch(id: babyId) {
            currentBabyStore.upsert(BabyProfile(record: record))
        }
    }
}

private struct MainTabPlaceholderScreen: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        NavigationStack {
            VStack(spacing: DSSpacing.lg) {
                Image(systemName: icon)
                    .font(DSTypography.largeTitle)
                    .foregroundStyle(DSColors.primary)

                Text(title)
                    .font(DSTypography.title)
                    .foregroundStyle(DSColors.textPrimary)

                Text(subtitle)
                    .font(DSTypography.subheadline)
                    .foregroundStyle(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(DSSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColors.background)
            .navigationTitle(title)
        }
    }
}

// MARK: - Shell State

@MainActor
final class MainTabShellState: ObservableObject {
    let appDatabase: AppDatabase

    init(database: AppDatabase) {
        appDatabase = database
    }

    static func makeDatabase() -> AppDatabase {
        (try? openDatabase()) ?? (try! AppDatabase.makeInMemory())
    }

    private static func openDatabase() throws -> AppDatabase {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BabyCamera", isDirectory: true)
        try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        return try AppDatabase.make(at: supportURL.appendingPathComponent("app.sqlite").path)
    }
}

// MARK: - Database Holder

@MainActor
final class AppDatabaseHolder: ObservableObject {
    let database: AppDatabase

    init() {
        database = (try? Self.openDatabase()) ?? (try! AppDatabase.makeInMemory())
    }

    private static func openDatabase() throws -> AppDatabase {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BabyCamera", isDirectory: true)
        try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        return try AppDatabase.make(at: supportURL.appendingPathComponent("app.sqlite").path)
    }
}

#Preview {
    let coordinator = AccountCoordinator()
    let babyStore = CurrentBabyEnvironment(restorePersistedSelection: false)
    return MainTabShellView(session: AuthSession(userId: "preview", isNewUser: false, profile: nil))
        .environmentObject(coordinator)
        .environmentObject(babyStore)
}
