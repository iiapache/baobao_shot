import BabyCameraCredit
import BabyCameraNetwork
import Foundation

public enum AITaskProgressState: Equatable {
    case tracking
    case succeeded
    case failure(AITaskFailurePresentation)
    case appealing

    public var isTerminal: Bool {
        switch self {
        case .tracking, .appealing:
            return false
        case .succeeded, .failure:
            return true
        }
    }
}

@MainActor
public final class AITaskProgressViewModel: ObservableObject {
    @Published public private(set) var state: AITaskProgressState = .tracking
    @Published public private(set) var snapshot: AITaskSnapshot?
    @Published public var isAppealSheetPresented = false
    @Published public var appealReason = ""
    @Published public var appealErrorMessage: String?

    public let taskId: String
    public let playName: String

    private let coordinator: AITaskCoordinator
    private let appealService: any AITaskAppealing
    private weak var creditService: (any CreditServing)?
    private var observationTask: Task<Void, Never>?

    public init(
        created: AITaskCreatedData,
        playName: String,
        coordinator: AITaskCoordinator,
        appealService: any AITaskAppealing,
        creditService: (any CreditServing)? = nil
    ) {
        self.taskId = created.taskId
        self.playName = playName
        self.coordinator = coordinator
        self.appealService = appealService
        self.creditService = creditService
        self.snapshot = AITaskSnapshot(created: created)
        creditService?.applyBalanceFromAITask(created.balanceAfter)
    }

    deinit {
        observationTask?.cancel()
    }

    public func start() async {
        guard observationTask == nil else { return }
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await update in await self.coordinator.updates {
                await self.apply(update)
            }
        }

        if let existing = await coordinator.snapshot(taskId: taskId) {
            apply(existing)
        }
    }

    public func presentAppealSheet() {
        guard case let .failure(presentation) = state, presentation.canAppeal else { return }
        appealReason = ""
        appealErrorMessage = nil
        isAppealSheetPresented = true
    }

    public func dismissAppealSheet() {
        isAppealSheetPresented = false
        appealReason = ""
    }

    public func submitAppeal() async {
        guard case let .failure(presentation) = state, presentation.canAppeal else { return }

        let trimmed = appealReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appealErrorMessage = "请填写申诉原因"
            return
        }

        state = .appealing
        appealErrorMessage = nil
        isAppealSheetPresented = false

        do {
            let result = try await appealService.appeal(taskId: taskId, reason: trimmed)
            let appealedSnapshot = AITaskSnapshot(
                taskId: taskId,
                phase: .appealed,
                serverState: result.state,
                costCredits: snapshot?.costCredits,
                balanceAfter: snapshot?.balanceAfter,
                failureReason: snapshot?.failureReason,
                updatedAt: Date()
            )
            snapshot = appealedSnapshot
            if let nextPresentation = AITaskOutcomeMapper.presentation(for: appealedSnapshot) {
                state = .failure(nextPresentation)
            }
            appealReason = ""
        } catch let error as APIError {
            state = .failure(presentation)
            appealErrorMessage = error.message
        } catch {
            state = .failure(presentation)
            appealErrorMessage = "申诉提交失败，请稍后重试"
        }
    }

    public func clearAppealError() {
        appealErrorMessage = nil
    }

    private func apply(_ update: AITaskSnapshot) {
        guard update.taskId == taskId else { return }
        snapshot = update

        switch update.phase {
        case .succeeded, .downloaded:
            state = .succeeded
        case .failed, .rejected, .appealed:
            if let presentation = AITaskOutcomeMapper.presentation(for: update) {
                state = .failure(presentation)
                if let balanceAfter = update.balanceAfter {
                    creditService?.applyBalanceFromAITask(balanceAfter)
                }
            }
        case .submitted, .pending, .running:
            if !state.isTerminal {
                state = .tracking
            }
        }
    }
}
