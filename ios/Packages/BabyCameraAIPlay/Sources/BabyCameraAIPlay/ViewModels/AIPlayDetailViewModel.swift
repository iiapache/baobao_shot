import BabyCameraCredit
import BabyCameraNetwork
import Foundation

public enum AIPlayDetailState: Equatable {
    case idle
    case loadingPreview
    case ready
    case confirming
    case submitting
    case submitted
    case error(String)

    public var isBusy: Bool {
        switch self {
        case .loadingPreview, .submitting:
            return true
        default:
            return false
        }
    }

    public var errorMessage: String? {
        if case let .error(message) = self {
            return message
        }
        return nil
    }
}

public enum AIPlayDetailNavigation: Equatable {
    case recharge
    case signIn
}

@MainActor
public final class AIPlayDetailViewModel: ObservableObject {
    @Published public private(set) var state: AIPlayDetailState = .idle
    @Published public private(set) var preview: CreditPreview?
    @Published public private(set) var createdTask: AITaskCreatedData?
    @Published public private(set) var selectedDurationSeconds: Int?
    @Published public var pendingNavigation: AIPlayDetailNavigation?

    public let play: AIPlay
    public let submissionContext: AIPlaySubmissionContext

    private let previewService: any CreditPreviewServing
    private let submitService: any AITaskSubmitting
    private weak var creditService: (any CreditServing)?

    public init(
        play: AIPlay,
        submissionContext: AIPlaySubmissionContext,
        previewService: any CreditPreviewServing,
        submitService: any AITaskSubmitting,
        creditService: (any CreditServing)? = nil,
        selectedDurationSeconds: Int? = nil
    ) {
        self.play = play
        self.submissionContext = submissionContext
        self.previewService = previewService
        self.submitService = submitService
        self.creditService = creditService
        if let selectedDurationSeconds {
            self.selectedDurationSeconds = selectedDurationSeconds
        } else if play.kind == .video {
            self.selectedDurationSeconds = play.durationTiers
                .sorted { $0.durationSeconds < $1.durationSeconds }
                .first?
                .durationSeconds
        }
    }

    public func loadPreview() async {
        guard !state.isBusy else { return }
        state = .loadingPreview
        pendingNavigation = nil
        defer {
            if state == .loadingPreview {
                state = .ready
            }
        }

        do {
            preview = try await previewService.preview(
                play: play,
                durationSeconds: selectedDurationSeconds
            )
            state = .ready
        } catch {
            state = .error(mapError(error))
        }
    }

    public func selectDuration(_ seconds: Int) {
        guard play.kind == .video, play.durationTiers.contains(where: { $0.durationSeconds == seconds }) else {
            return
        }
        selectedDurationSeconds = seconds
        if state == .ready || state.errorMessage != nil {
            Task { await loadPreview() }
        }
    }

    public func requestSubmit() {
        guard let preview, state == .ready || state.errorMessage != nil else { return }

        if !preview.hasSufficientCredit {
            pendingNavigation = .recharge
            return
        }
        state = .confirming
    }

    public func cancelConfirmation() {
        guard state == .confirming else { return }
        state = .ready
    }

    public func confirmSubmit() async {
        guard state == .confirming else { return }
        state = .submitting
        pendingNavigation = nil

        do {
            let result = try await submitService.submit(
                play: play,
                context: submissionContext,
                durationSeconds: selectedDurationSeconds
            )
            createdTask = result
            creditService?.applyBalanceFromAITask(result.balanceAfter)
            state = .submitted
        } catch {
            if let apiError = error as? APIError, apiError.code == .aiInsufficientCredit {
                pendingNavigation = .recharge
                state = .ready
                return
            }
            state = .error(mapError(error))
        }
    }

    public func requestSignIn() {
        pendingNavigation = .signIn
    }

    public func clearPendingNavigation() {
        pendingNavigation = nil
    }

    public func clearError() {
        guard state.errorMessage != nil else { return }
        state = .ready
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        if let previewError = error as? CreditPreviewServiceError {
            switch previewError {
            case .notAuthenticated:
                return "请先登录"
            }
        }
        if let submitError = error as? AITaskSubmitServiceError {
            switch submitError {
            case .notAuthenticated:
                return "请先登录"
            }
        }
        return "操作失败，请稍后重试"
    }
}
