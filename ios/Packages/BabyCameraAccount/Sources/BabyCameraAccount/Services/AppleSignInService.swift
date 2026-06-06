import AuthenticationServices
import UIKit

@MainActor
public final class AppleSignInService: NSObject, AppleSignInProviding, @unchecked Sendable {
    private var continuation: CheckedContinuation<AppleSignInCredential, Error>?

    public override init() {
        super.init()
    }

    public func signIn() async throws -> AppleSignInCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func resume(with result: Result<AppleSignInCredential, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}

extension AppleSignInService: ASAuthorizationControllerDelegate {
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityData = credential.identityToken,
              let identityToken = String(data: identityData, encoding: .utf8),
              let codeData = credential.authorizationCode,
              let authorizationCode = String(data: codeData, encoding: .utf8) else {
            resume(with: .failure(AppleSignInError.invalidCredential))
            return
        }

        let nickname = credential.fullName?.givenName
        resume(
            with: .success(
                AppleSignInCredential(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    nickname: nickname
                )
            )
        )
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            resume(with: .failure(AppleSignInError.cancelled))
            return
        }
        resume(with: .failure(error))
    }
}

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        if let window = windowScene?.windows.first(where: \.isKeyWindow) {
            return window
        }
        return UIWindow()
    }
}
