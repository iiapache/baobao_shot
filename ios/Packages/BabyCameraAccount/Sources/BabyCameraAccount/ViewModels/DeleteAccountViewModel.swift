import BabyCameraNetwork
import Foundation

@MainActor
public final class DeleteAccountViewModel: ObservableObject {
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public private(set) var deletionResult: AccountDeletionResult?

    private let authService: AuthService

    public init(authService: AuthService) {
        self.authService = authService
    }

    public func confirmDeletion() async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            deletionResult = try await authService.deleteAccount()
            return true
        } catch {
            errorMessage = mapError(error)
            return false
        }
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        return "注销失败，请稍后重试"
    }
}
