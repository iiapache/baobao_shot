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
        if session.isNewUser {
            phase = .onboarding(session)
        } else {
            phase = .authenticated(session)
        }
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
}

public struct AccountRootView<AuthenticatedContent: View>: View {
    @StateObject private var coordinator: AccountCoordinator
    private let authenticatedContent: (AuthSession) -> AuthenticatedContent

    public init(
        coordinator: AccountCoordinator,
        @ViewBuilder authenticatedContent: @escaping (AuthSession) -> AuthenticatedContent
    ) {
        _coordinator = StateObject(wrappedValue: coordinator)
        self.authenticatedContent = authenticatedContent
    }

    public init(
        @ViewBuilder authenticatedContent: @escaping (AuthSession) -> AuthenticatedContent
    ) {
        self.init(coordinator: AccountCoordinator(), authenticatedContent: authenticatedContent)
    }

    public var body: some View {
        Group {
            switch coordinator.phase {
            case .bootstrapping:
                ProgressView("正在恢复登录状态…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .login:
                LoginView(viewModel: coordinator.makeLoginViewModel()) { session in
                    coordinator.handleAuthenticated(session)
                }
            case let .authenticated(session), let .onboarding(session):
                authenticatedContent(session)
                    .environmentObject(coordinator)
            }
        }
        .task {
            await coordinator.bootstrap()
        }
    }
}
