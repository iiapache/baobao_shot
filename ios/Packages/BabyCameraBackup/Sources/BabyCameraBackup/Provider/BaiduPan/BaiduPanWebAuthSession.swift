#if canImport(AuthenticationServices) && canImport(UIKit)
import AuthenticationServices
import UIKit

@MainActor
protocol BaiduPanWebAuthSessionStarting: Sendable {
    func start(
        url: URL,
        callbackURLScheme: String,
        completion: @escaping @Sendable (Result<URL, Error>) -> Void
    )
}

@MainActor
final class BaiduPanWebAuthSessionStarter: NSObject, BaiduPanWebAuthSessionStarting, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func start(
        url: URL,
        callbackURLScheme: String,
        completion: @escaping @Sendable (Result<URL, Error>) -> Void
    ) {
        session?.cancel()
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackURLScheme
        ) { callbackURL, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let callbackURL else {
                completion(.failure(BaiduPanProviderError.authorizationFailed("missing callback url")))
                return
            }
            completion(.success(callbackURL))
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        self.session = session
        if !session.start() {
            completion(.failure(BaiduPanProviderError.authorizationFailed("failed to start oauth session")))
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        if let window = windowScene?.windows.first(where: \.isKeyWindow) {
            return window
        }
        if let window = windowScene?.windows.first {
            return window
        }
        return ASPresentationAnchor()
    }
}
#endif
