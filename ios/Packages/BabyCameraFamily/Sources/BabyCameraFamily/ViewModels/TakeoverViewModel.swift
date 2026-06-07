import BabyCameraNetwork
import Foundation

@MainActor
public final class TakeoverViewModel: ObservableObject {
    @Published public private(set) var state: FamilyAdminFlowState = .idle
    @Published public private(set) var vote: TakeoverVoteResult?

    public let familyId: String
    public let familyName: String
    public let isAdmin: Bool
    public let canInitiate: Bool

    private let familyService: FamilyService

    public init(
        familyId: String,
        familyName: String,
        isAdmin: Bool,
        currentRole: FamilyRole,
        familyService: FamilyService
    ) {
        self.familyId = familyId
        self.familyName = familyName
        self.isAdmin = isAdmin
        self.canInitiate = currentRole == .family
        self.familyService = familyService
    }

    public var showsVoteProgress: Bool {
        vote?.isActive == true
    }

    public func requestInitiateConfirmation() {
        guard canInitiate, vote == nil else { return }
        state = .confirming
    }

    public func requestCancelObjectionConfirmation() {
        guard isAdmin, vote?.status == .objectionPeriod else { return }
        state = .confirming
    }

    public func cancelConfirmation() {
        guard state == .confirming else { return }
        state = vote == nil ? .idle : .idle
    }

    public func initiateTakeover() async {
        guard canInitiate, state == .confirming || state == .idle else { return }

        state = .submitting
        do {
            let result = try await familyService.takeover(familyId: familyId, choice: nil)
            vote = result
            applyVoteResult(result)
            FamilyPushNotificationCopy.track(
                FamilyPushNotificationCopy.AnalyticsEvent.takeoverVote,
                parameters: [
                    "familyId": familyId,
                    "voteId": result.voteId,
                    "action": "initiate",
                ]
            )
        } catch {
            state = .error(mapError(error))
        }
    }

    public func confirmInitiate() async {
        guard state == .confirming else { return }
        await initiateTakeover()
    }

    public func vote(approve: Bool) async {
        guard canInitiate, vote?.status == .voting else { return }

        state = .submitting
        do {
            let result = try await familyService.takeover(
                familyId: familyId,
                choice: approve ? .approve : .reject
            )
            vote = result
            applyVoteResult(result)
            FamilyPushNotificationCopy.track(
                FamilyPushNotificationCopy.AnalyticsEvent.takeoverVote,
                parameters: [
                    "familyId": familyId,
                    "voteId": result.voteId,
                    "action": approve ? "approve" : "reject",
                ]
            )
        } catch {
            state = .error(mapError(error))
        }
    }

    public func cancelObjection() async {
        guard isAdmin, vote?.status == .objectionPeriod else { return }

        state = .submitting
        do {
            let result = try await familyService.takeover(familyId: familyId, choice: nil)
            vote = result
            state = .success
        } catch {
            state = .error(mapError(error))
        }
    }

    public func confirmCancelObjection() async {
        guard state == .confirming else { return }
        await cancelObjection()
    }

    public func dismissTerminalState() {
        if state == .success {
            state = vote?.isActive == true ? .idle : .idle
        }
    }

    public func clearError() {
        guard state.errorMessage != nil else { return }
        state = .idle
    }

    public func reset() {
        state = .idle
        vote = nil
    }

    internal func replaceVote(_ vote: TakeoverVoteResult?) {
        self.vote = vote
    }

    public var initiatePushCopy: (title: String, body: String) {
        (
            FamilyPushNotificationCopy.takeoverVoteStartedTitle,
            FamilyPushNotificationCopy.takeoverVoteStartedBody(familyName: familyName)
        )
    }

    public var objectionPeriodPushCopy: (title: String, body: String) {
        (
            FamilyPushNotificationCopy.takeoverObjectionPeriodTitle,
            FamilyPushNotificationCopy.takeoverObjectionPeriodBody(days: 7)
        )
    }

    private func applyVoteResult(_ result: TakeoverVoteResult) {
        switch result.status {
        case .voting:
            state = .idle
        case .objectionPeriod:
            state = .success
        case .completed:
            state = .success
        case .cancelled, .rejected:
            state = .success
        }
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError.rawCode {
            case "FAMILY_ADMIN_ACTIVE":
                return "管理员近期仍活跃，暂不可发起接管"
            case "FAMILY_TAKEOVER_NOT_ELIGIBLE":
                return "你暂无权限参与接管"
            case "FAMILY_TAKEOVER_ALREADY_VOTED":
                return "你已经投过票了"
            case "FAMILY_TAKEOVER_IN_PROGRESS":
                return "已有进行中的接管投票"
            case "FAMILY_TAKEOVER_NO_ACTIVE_VOTE":
                return "当前没有进行中的接管投票"
            default:
                return apiError.message
            }
        }
        if let familyError = error as? FamilyServiceError {
            switch familyError {
            case .notAuthenticated:
                return "请先登录"
            }
        }
        return "操作失败，请稍后重试"
    }
}
