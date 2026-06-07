import DesignSystem
import Foundation
import SwiftUI

@MainActor
public final class AccountCoordinator: ObservableObject {
    public enum Phase: Equatable {
        case bootstrapping
        case login
        case authenticated(AuthSession)
        case onboarding(AuthSession)
    }

    @Published public private(set) var phase: Phase = .bootstrapping
    @Published public private(set) var session: AuthSession?

    public let authService: AuthService
    private let appleSignIn: AppleSignInProviding

    public init(
        authService: AuthService = AuthService(),
        appleSignIn: AppleSignInProviding? = nil
    ) {
        self.authService = authService
        self.appleSignIn = appleSignIn ?? AppleSignInService()
    }

    public func bootstrap() async {
        phase = .bootstrapping
        guard authService.isAuthenticated else {
            transitionToLogin()
            return
        }

        do {
            let restored = try await authService.restoreSession()
            handleAuthenticated(restored)
        } catch {
            authService.tokenStore.clear()
            transitionToLogin()
        }
    }

    public func handleAuthenticated(_ session: AuthSession) {
        self.session = session
        if needsOnboarding(for: session) {
            phase = .onboarding(session)
        } else {
            phase = .authenticated(session)
        }
    }

    public func completeOnboarding(_ session: AuthSession) {
        self.session = session
        phase = .authenticated(session)
    }

    public func handleLogout() async {
        do {
            try await authService.logout()
        } catch {
            authService.tokenStore.clear()
        }
        session = nil
        transitionToLogin()
    }

    public func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(authService: authService, appleSignIn: appleSignIn)
    }

    public func makeDeleteAccountViewModel() -> DeleteAccountViewModel {
        DeleteAccountViewModel(authService: authService)
    }

    private func transitionToLogin() {
        session = nil
        phase = .login
    }

    private func needsOnboarding(for session: AuthSession) -> Bool {
        let completionKey = "com.babycamera.onboarding.completed.\(session.userId)"
        if UserDefaults.standard.bool(forKey: completionKey) {
            return false
        }
        return session.isNewUser
    }
}

public struct AccountRootView<AuthenticatedContent: View, OnboardingContent: View>: View {
    @StateObject private var coordinator: AccountCoordinator
    private let authenticatedContent: (AuthSession) -> AuthenticatedContent
    private let onboardingContent: (AuthSession) -> OnboardingContent

    public init(
        coordinator: AccountCoordinator,
        @ViewBuilder authenticatedContent: @escaping (AuthSession) -> AuthenticatedContent,
        @ViewBuilder onboardingContent: @escaping (AuthSession) -> OnboardingContent
    ) {
        _coordinator = StateObject(wrappedValue: coordinator)
        self.authenticatedContent = authenticatedContent
        self.onboardingContent = onboardingContent
    }

    public init(
        @ViewBuilder authenticatedContent: @escaping (AuthSession) -> AuthenticatedContent,
        @ViewBuilder onboardingContent: @escaping (AuthSession) -> OnboardingContent
    ) {
        self.init(
            coordinator: AccountCoordinator(),
            authenticatedContent: authenticatedContent,
            onboardingContent: onboardingContent
        )
    }

    public var body: some View {
        Group {
            switch coordinator.phase {
            case .bootstrapping:
                ProgressView(L10n.string("login.restoring_session"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .login:
                LoginView(viewModel: coordinator.makeLoginViewModel()) { session in
                    coordinator.handleAuthenticated(session)
                }
            case let .onboarding(session):
                onboardingContent(session)
                    .environmentObject(coordinator)
            case let .authenticated(session):
                authenticatedContent(session)
                    .environmentObject(coordinator)
            }
        }
        .task {
            await coordinator.bootstrap()
        }
    }
}
