import BabyCameraNetwork
import Foundation

@MainActor
public final class LoginViewModel: ObservableObject {
    @Published public var phone = ""
    @Published public var verificationCode = ""
    @Published public var isLoading = false
    @Published public var isSendingCode = false
    @Published public var errorMessage: String?
    @Published public private(set) var codeCooldownSeconds = 0

    private let authService: AuthService
    private let appleSignIn: AppleSignInProviding
    private var cooldownTask: Task<Void, Never>?

    public init(authService: AuthService, appleSignIn: AppleSignInProviding) {
        self.authService = authService
        self.appleSignIn = appleSignIn
    }

    deinit {
        cooldownTask?.cancel()
    }

    public var canSendCode: Bool {
        phone.count >= 11 && codeCooldownSeconds == 0 && !isSendingCode && !isLoading
    }

    public var canSubmitPhoneLogin: Bool {
        phone.count >= 11 && verificationCode.count >= 4 && !isLoading
    }

    public func signInWithApple() async -> AuthSession? {
        guard !isLoading else { return nil }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let credential = try await appleSignIn.signIn()
            return try await authService.loginWithApple(credential)
        } catch let error as AppleSignInError where error == .cancelled {
            return nil
        } catch {
            errorMessage = mapError(error)
            return nil
        }
    }

    public func sendVerificationCode() async {
        guard canSendCode else { return }
        isSendingCode = true
        errorMessage = nil
        defer { isSendingCode = false }

        do {
            try await authService.sendPhoneVerificationCode(phone: phone)
            startCooldown(seconds: 60)
        } catch {
            errorMessage = mapError(error)
        }
    }

    public func loginWithPhone() async -> AuthSession? {
        guard canSubmitPhoneLogin else { return nil }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            return try await authService.loginWithPhone(phone: phone, code: verificationCode)
        } catch {
            errorMessage = mapError(error)
            return nil
        }
    }

    private func startCooldown(seconds: Int) {
        cooldownTask?.cancel()
        codeCooldownSeconds = seconds
        cooldownTask = Task { [weak self] in
            guard let self else { return }
            while self.codeCooldownSeconds > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.codeCooldownSeconds -= 1
            }
        }
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        if let authError = error as? AuthServiceError {
            switch authError {
            case .notAuthenticated:
                return "请先登录"
            case .sessionRestoreFailed:
                return "会话恢复失败，请重新登录"
            }
        }
        return "操作失败，请稍后重试"
    }
}
