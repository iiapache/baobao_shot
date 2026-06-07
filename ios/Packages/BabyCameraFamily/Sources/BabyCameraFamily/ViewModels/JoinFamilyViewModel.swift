import BabyCameraNetwork
import Foundation

@MainActor
public final class JoinFamilyViewModel: ObservableObject {
    @Published public var inviteCode = ""
    @Published public var scannedPayload: String?
    @Published public var selectedRelation: FamilyRelation = .mom
    @Published public var nickname = ""
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    private let familyService: FamilyService

    public init(familyService: FamilyService) {
        self.familyService = familyService
    }

    public var canSubmit: Bool {
        !effectiveCode.isEmpty && !isLoading
    }

    public var effectiveCode: String {
        if !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let scannedPayload,
           let code = try? familyService.invitationCodeService.extractInviteCode(from: scannedPayload) {
            return code
        }
        return ""
    }

    public func handleScannedContent(_ content: String) {
        scannedPayload = content
        errorMessage = nil
        do {
            let code = try familyService.invitationCodeService.extractInviteCode(from: content)
            inviteCode = code
        } catch {
            errorMessage = "无法识别二维码，请手动输入邀请码"
        }
    }

    public func join() async -> JoinFamilyResult? {
        guard canSubmit else { return nil }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = trimmedNickname.isEmpty ? nil : trimmedNickname

            if let scannedPayload, !scannedPayload.isEmpty {
                return try await familyService.joinFamily(
                    fromScannedContent: scannedPayload,
                    relation: selectedRelation,
                    nickname: displayName
                )
            }
            return try await familyService.joinFamily(
                code: effectiveCode,
                relation: selectedRelation,
                nickname: displayName
            )
        } catch {
            errorMessage = mapError(error)
            return nil
        }
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError.code {
            case .familyInviteExpired:
                return "邀请码已过期"
            case .familyInviteUsedUp:
                return "邀请码已用尽"
            case .familyMemberLimit:
                return "家庭成员已达上限"
            case .familyAlreadyMember:
                return "您已是该家庭成员"
            default:
                return apiError.message
            }
        }
        if let inviteError = error as? InvitationCodeServiceError {
            switch inviteError {
            case .invalidSignature:
                return "二维码签名无效"
            case .invalidPayload:
                return "无法识别邀请信息"
            default:
                return "邀请码无效"
            }
        }
        return "加入失败，请稍后重试"
    }
}
