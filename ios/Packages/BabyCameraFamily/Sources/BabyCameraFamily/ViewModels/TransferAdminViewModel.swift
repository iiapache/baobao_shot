import BabyCameraNetwork
import Foundation

@MainActor
public final class TransferAdminViewModel: ObservableObject {
    @Published public private(set) var state: FamilyAdminFlowState = .idle
    @Published public private(set) var targetMember: FamilyMember?
    @Published public private(set) var result: TransferAdminResult?

    public let familyId: String
    public let familyName: String
    public let candidates: [FamilyMember]

    private let familyService: FamilyService

    public init(
        familyId: String,
        familyName: String,
        candidates: [FamilyMember],
        familyService: FamilyService
    ) {
        self.familyId = familyId
        self.familyName = familyName
        self.candidates = candidates
        self.familyService = familyService
    }

    public var canProceed: Bool {
        targetMember != nil && state == .idle
    }

    public func selectTarget(_ member: FamilyMember) {
        guard !state.isBusy else { return }
        targetMember = member
        if case .error = state {
            state = .idle
        }
    }

    public func requestConfirmation() {
        guard targetMember != nil, state == .idle || state.errorMessage != nil else { return }
        state = .confirming
    }

    public func cancelConfirmation() {
        guard state == .confirming else { return }
        state = .idle
    }

    public func confirmTransfer() async {
        guard state == .confirming, let target = targetMember else { return }

        state = .submitting
        do {
            let transferResult = try await familyService.transferAdmin(
                familyId: familyId,
                targetUserId: target.id
            )
            result = transferResult
            state = .success
            FamilyPushNotificationCopy.track(
                FamilyPushNotificationCopy.AnalyticsEvent.transfer,
                parameters: [
                    "familyId": familyId,
                    "newAdminUserId": transferResult.newAdminUserId,
                ]
            )
        } catch {
            state = .error(mapError(error))
        }
    }

    public func dismissSuccess() {
        guard state == .success else { return }
        state = .idle
    }

    public func clearError() {
        guard state.errorMessage != nil else { return }
        state = .idle
    }

    public func reset() {
        state = .idle
        targetMember = nil
        result = nil
    }

    public func pushCopyForNewAdmin(previousAdminName: String) -> (title: String, body: String) {
        (
            FamilyPushNotificationCopy.transferToNewAdminTitle,
            FamilyPushNotificationCopy.transferToNewAdminBody(previousAdminName: previousAdminName)
        )
    }

    public func pushCopyForMembers(newAdminName: String) -> (title: String, body: String) {
        (
            FamilyPushNotificationCopy.transferToMembersTitle,
            FamilyPushNotificationCopy.transferToMembersBody(newAdminName: newAdminName)
        )
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError.rawCode {
            case "FAMILY_TRANSFER_TARGET_INVALID":
                return "无法转让给该成员，请选择其他家人"
            case "FAMILY_TRANSFER_SELF":
                return "不能转让给自己"
            case "FAMILY_NOT_ADMIN":
                return "仅管理员可以转让权限"
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
        return "转让失败，请稍后重试"
    }
}
