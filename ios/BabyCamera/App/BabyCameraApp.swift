import BabyCameraAccount
import BabyCameraBaby
import BabyCameraDiagnostics
import BabyCameraFamilyFeed
import BabyCameraNetwork
import BabyCameraNotification
import BabyCameraOnboarding
import DesignSystem
import SwiftUI

@main
struct BabyCameraApp: App {
    @UIApplicationDelegateAdaptor(NotificationAppDelegate.self) private var appDelegate
    @StateObject private var currentBabyStore = CurrentBabyEnvironment(restorePersistedSelection: true)

    init() {
        CrashReportingBootstrap.configureIfNeeded()
        WechatOpenSDKRegistrar.registerIfNeeded()
        UITestBootstrap.configureIfNeeded()
        P6E2EBootstrap.configureIfNeeded()
        NotificationIntegrationFactory.configure(
            tokenStore: KeychainTokenStore(),
            urlSession: UITestBootstrap.isEnabled ? MockURLProtocol.makeSession() : .shared
        )
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .environmentObject(currentBabyStore)
                .trackAnalyticsLifecycle()
                .onOpenURL { url in
                    _ = WechatOpenSDKRegistrar.handleOpenURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    _ = WechatOpenSDKRegistrar.handleUniversalLink(activity)
                }
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
                MainTabShellView(session: session)
            } onboardingContent: { session in
                OnboardingShellView(session: session, useMockServices: true, babyStore: currentBabyStore)
            }
        } else {
            AccountRootView { session in
                MainTabShellView(session: session)
                    .task {
                        await registerPushTokenIfNeeded()
                    }
            } onboardingContent: { session in
                OnboardingShellView(session: session, useMockServices: false, babyStore: currentBabyStore)
            }
        }
    }

    private func registerPushTokenIfNeeded() async {
        do {
            _ = try await NotificationBootstrap.registerCurrentTokenIfAvailable()
        } catch {
            #if DEBUG
            print("APNs token register skipped: \(error.localizedDescription)")
            #endif
        }
    }
}

private struct OnboardingShellView: View {
    let session: AuthSession
    let useMockServices: Bool
    @ObservedObject var babyStore: CurrentBabyEnvironment
    @EnvironmentObject private var coordinator: AccountCoordinator

    var body: some View {
        OnboardingFlowView(
            session: session,
            coordinator: coordinator,
            service: useMockServices
                ? UITestBootstrap.makeOnboardingService(tokenStore: coordinator.authService.tokenStore)
                : OnboardingService(),
            currentBabyStore: babyStore
        ) { _ in
            // AccountCoordinator.completeOnboarding 已在 OnboardingFlowView 内调用
        }
    }
}

#Preview {
    let coordinator = AccountCoordinator()
    let babyStore = CurrentBabyEnvironment(restorePersistedSelection: false)
    return AccountRootView(coordinator: coordinator) { session in
        MainTabShellView(session: session)
            .environmentObject(coordinator)
            .environmentObject(babyStore)
    } onboardingContent: { session in
        OnboardingShellView(session: session, useMockServices: false, babyStore: babyStore)
            .environmentObject(coordinator)
            .environmentObject(babyStore)
    }
}
