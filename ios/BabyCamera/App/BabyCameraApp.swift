import BabyCameraAccount
import BabyCameraDiagnostics
import BabyCameraOnboarding
import BabyCameraSettings
import Database
import DesignSystem
import SwiftUI

@main
struct BabyCameraApp: App {
    init() {
        CrashReportingBootstrap.configureIfNeeded()
        UITestBootstrap.configureIfNeeded()
        P6E2EBootstrap.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .trackAnalyticsLifecycle()
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if UITestLaunchConfiguration.isP2E2EMode {
            P2E2ERootView(offlineMode: UITestLaunchConfiguration.isOfflineMode)
        } else if UITestLaunchConfiguration.isP6E2EMode {
            P6E2ERootView()
        } else if UITestBootstrap.isEnabled {
            AccountRootView(coordinator: UITestBootstrap.makeCoordinator()) { session in
                MainShellView(session: session)
            } onboardingContent: { session in
                OnboardingShellView(session: session, useMockServices: true)
            }
        } else {
            AccountRootView { session in
                MainShellView(session: session)
            } onboardingContent: { session in
                OnboardingShellView(session: session, useMockServices: false)
            }
        }
    }
}

private struct OnboardingShellView: View {
    let session: AuthSession
    let useMockServices: Bool
    @EnvironmentObject private var coordinator: AccountCoordinator

    var body: some View {
        OnboardingFlowView(
            session: session,
            coordinator: coordinator,
            service: useMockServices
                ? UITestBootstrap.makeOnboardingService(tokenStore: coordinator.authService.tokenStore)
                : OnboardingService()
        ) { _ in
            // AccountCoordinator.completeOnboarding 已在 OnboardingFlowView 内调用
        }
    }
}

private struct MainShellView: View {
    let session: AuthSession
    @EnvironmentObject private var coordinator: AccountCoordinator
    @StateObject private var appDatabaseHolder = AppDatabaseHolder()

    var body: some View {
        NavigationStack {
            VStack(spacing: DSSpacing.lg) {
                Image(systemName: "camera.fill")
                    .font(DSTypography.largeTitle)
                    .foregroundStyle(DSColors.primary)
                Text("宝宝成长相机")
                    .font(DSTypography.title)
                    .foregroundStyle(DSColors.textPrimary)
                Text(session.profile?.nickname ?? "欢迎回来")
                    .font(DSTypography.subheadline)
                    .foregroundStyle(DSColors.textSecondary)
                    .accessibilityIdentifier("homeWelcomeLabel")

                ConsentGatedContent(feature: .camera, profile: session.profile, userId: session.userId) {
                    Label("打开相机", systemImage: "camera")
                        .font(DSTypography.bodyEmphasis)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DSColors.primaryMuted)
                        .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
                }

                NavigationLink {
                    SettingsRootView(
                        context: SettingsIntegrationContextFactory.make(
                            session: session,
                            accountCoordinator: coordinator,
                            appDatabase: appDatabaseHolder.database
                        )
                    )
                } label: {
                    Label("设置", systemImage: "gearshape.fill")
                        .font(DSTypography.bodyEmphasis)
                }
                .buttonStyle(.borderedProminent)
                .tint(DSColors.primary)
                .accessibilityIdentifier("settingsRootLink")

                NavigationLink {
                    AccountSettingsView(coordinator: coordinator)
                } label: {
                    Label("账号设置", systemImage: "person.crop.circle")
                        .font(DSTypography.bodyEmphasis)
                }
                .buttonStyle(.borderedProminent)
                .tint(DSColors.primary)
                .accessibilityIdentifier("accountSettingsLink")

                NavigationLink {
                    DesignSystemCatalogView()
                } label: {
                    Label("Design System Catalog", systemImage: "paintpalette.fill")
                        .font(DSTypography.bodyEmphasis)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColors.background)
            .navigationTitle("首页")
            .accessibilityIdentifier("mainHomeView")
        }
    }
}

@MainActor
private final class AppDatabaseHolder: ObservableObject {
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
    return AccountRootView(coordinator: coordinator) { session in
        MainShellView(session: session)
            .environmentObject(coordinator)
    } onboardingContent: { session in
        OnboardingShellView(session: session, useMockServices: false)
            .environmentObject(coordinator)
    }
}
