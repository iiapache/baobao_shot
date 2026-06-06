import Foundation

public struct AppleSignInCredential: Sendable, Equatable {
    public let identityToken: String
    public let authorizationCode: String
    public let nickname: String?

    public init(identityToken: String, authorizationCode: String, nickname: String? = nil) {
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.nickname = nickname
    }
}

public enum AppleSignInError: Error, Equatable, Sendable {
    case cancelled
    case missingCredential
    case invalidCredential
}

public protocol AppleSignInProviding: Sendable {
    func signIn() async throws -> AppleSignInCredential
}
