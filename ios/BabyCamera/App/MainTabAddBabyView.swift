import BabyCameraAccount
import BabyCameraBaby
import BabyCameraNetwork
import BabyCameraOnboarding
import Database
import DesignSystem
import SwiftUI

/// 从顶栏切换器「添加宝宝」进入的创建流程。
struct MainTabAddBabyView: View {
    let session: AuthSession
    let appDatabase: AppDatabase
    @ObservedObject var currentBabyStore: CurrentBabyEnvironment

    @EnvironmentObject private var coordinator: AccountCoordinator
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: BabyEditViewModel?
    @State private var bootstrapError: String?
    @State private var isBootstrapping = true

    var body: some View {
        NavigationStack {
            Group {
                if isBootstrapping {
                    DSLoadingView(message: "准备中…")
                } else if let bootstrapError {
                    DSEmptyState(
                        systemImage: "figure.and.child.holdinghands",
                        title: "无法添加宝宝",
                        message: bootstrapError,
                        actionTitle: "重试"
                    ) {
                        Task { await bootstrap() }
                    }
                } else if let viewModel {
                    ConsentGatedContent(
                        feature: .babyCreate,
                        profile: session.profile,
                        userId: session.userId
                    ) {
                        BabyEditView(viewModel: viewModel) { _ in
                            dismiss()
                        }
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("取消") {
                                    dismiss()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("添加宝宝")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await bootstrap()
        }
    }

    private func bootstrap() async {
        isBootstrapping = true
        bootstrapError = nil
        defer { isBootstrapping = false }

        do {
            let familyId = try await MainTabBabyLoader.resolvePrimaryFamilyId(database: appDatabase)
            let tokenStore = coordinator.authService.tokenStore
            let regionConfig = RegionConfig(
                region: .cn,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                deviceId: UserDefaults.standard.string(forKey: "com.babycamera.deviceId") ?? UUID().uuidString
            )
            let session: URLSession = UITestBootstrap.isEnabled
                ? MockURLProtocol.makeSession()
                : NetworkSessionFactory.makeSession()
            let client = makeAuthenticatedClient(
                region: .cn,
                tokenStore: tokenStore,
                regionConfig: regionConfig,
                session: session
            )
            let babyService = BabyService(
                familyId: familyId,
                repository: appDatabase.makeBabyRepository(),
                client: client
            )
            viewModel = BabyEditViewModel(
                mode: .create,
                service: babyService,
                currentBabyStore: currentBabyStore
            )
        } catch {
            bootstrapError = error.localizedDescription
        }
    }
}
