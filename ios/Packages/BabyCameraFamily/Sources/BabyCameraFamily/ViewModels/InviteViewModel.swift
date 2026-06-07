import BabyCameraNetwork
import Foundation
import UIKit

@MainActor
public final class InviteViewModel: ObservableObject {
    @Published public private(set) var invitation: FamilyInvitation?
    @Published public private(set) var qrImage: UIImage?
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public private(set) var didCopyCode = false

    public let familyId: String
    private let familyService: FamilyService

    public init(familyId: String, familyService: FamilyService) {
        self.familyId = familyId
        self.familyService = familyService
    }

    public func generateInvitation() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let invite = try await familyService.createInvitation(familyId: familyId)
            invitation = invite
            qrImage = try familyService.invitationCodeService.generateQRImage(from: invite.qrPayload)
        } catch {
            errorMessage = mapError(error)
        }
    }

    public func copyInviteCode() {
        guard let code = invitation?.code else { return }
        familyService.invitationCodeService.copyInviteCodeToClipboard(code)
        didCopyCode = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            didCopyCode = false
        }
    }

    public func revokeInvitation() async {
        guard let code = invitation?.code else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await familyService.revokeInvitation(familyId: familyId, code: code)
            invitation = nil
            qrImage = nil
        } catch {
            errorMessage = mapError(error)
        }
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        if let inviteError = error as? InvitationCodeServiceError {
            switch inviteError {
            case .qrGenerationFailed:
                return "二维码生成失败"
            default:
                return "邀请码无效"
            }
        }
        return "操作失败，请稍后重试"
    }
}
