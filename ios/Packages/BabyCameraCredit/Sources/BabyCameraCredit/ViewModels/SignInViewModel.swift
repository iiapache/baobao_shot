import BabyCameraNetwork
import Foundation

@MainActor
public final class SignInViewModel: ObservableObject {
    public enum Phase: Equatable {
        case idle
        case signingIn
        case completed(SignInResult)
    }

    @Published public private(set) var phase: Phase = .idle
    @Published public var errorMessage: String?

    public let creditService: any CreditServing

    public init(creditService: any CreditServing) {
        self.creditService = creditService
    }

    public var signInAvailable: Bool {
        creditService.signInAvailable
    }

    public var currentStreak: Int {
        creditService.currentSignInStreak
    }

    public var todayCreditsHint: String {
        if let result = completedResult {
            return "今日已领取 \(result.grantedCredits) 积分"
        }
        if signInAvailable {
            if currentStreak > 0 {
                let next = SignInCredits.nextDayCredits(afterStreak: currentStreak)
                return "连续签到可领 \(SignInCredits.minCredits)–\(SignInCredits.maxCredits) 积分，明日预计 \(next) 积分"
            }
            return "连续签到可领 \(SignInCredits.minCredits)–\(SignInCredits.maxCredits) 积分"
        }
        if currentStreak > 0 {
            let tomorrow = SignInCredits.nextDayCredits(afterStreak: currentStreak)
            return "已连续签到 \(currentStreak) 天，明日预计 \(tomorrow) 积分"
        }
        return "今日已签到"
    }

    public var completedResult: SignInResult? {
        if case let .completed(result) = phase {
            return result
        }
        return nil
    }

    public func refresh() async {
        do {
            try await creditService.refreshBalance()
            if !signInAvailable, completedResult == nil, currentStreak > 0 {
                phase = .idle
            }
        } catch {
            errorMessage = mapError(error)
        }
    }

    public func signIn() async {
        guard signInAvailable, phase != .signingIn else { return }
        phase = .signingIn
        errorMessage = nil

        do {
            let result = try await creditService.signIn()
            phase = .completed(result)
        } catch {
            phase = .idle
            errorMessage = mapError(error)
        }
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError.code {
            case .creditSignInDone:
                return "今日已签到"
            default:
                return apiError.message
            }
        }
        if let creditError = error as? CreditServiceError {
            switch creditError {
            case .notAuthenticated:
                return "请先登录"
            }
        }
        return "签到失败，请稍后重试"
    }
}
