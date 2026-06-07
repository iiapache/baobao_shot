import BabyCameraNetwork
import Foundation

@MainActor
public final class FamilyMembersViewModel: ObservableObject {
    @Published public private(set) var members: [FamilyMember] = []
    @Published public private(set) var familyName: String = ""
    @Published public private(set) var currentRole: FamilyRole = .family
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    public let familyId: String
    public let familyService: FamilyService

    public init(familyId: String, familyService: FamilyService) {
        self.familyId = familyId
        self.familyService = familyService
    }

    public var isAdmin: Bool {
        currentRole == .admin
    }

    public var canInvite: Bool {
        isAdmin
    }

    public var transferCandidates: [FamilyMember] {
        members.filter { $0.role == .family }
    }

    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let detail = try await familyService.getFamily(familyId: familyId)
            familyName = detail.name
            currentRole = detail.role
            members = detail.members
        } catch {
            errorMessage = mapError(error)
        }
    }

    public func removeMember(_ member: FamilyMember) async {
        guard isAdmin, member.role != .admin else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await familyService.removeMember(familyId: familyId, userId: member.id)
            members.removeAll { $0.id == member.id }
        } catch {
            errorMessage = mapError(error)
        }
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        if let familyError = error as? FamilyServiceError {
            switch familyError {
            case .notAuthenticated:
                return "请先登录"
            }
        }
        return "加载失败，请稍后重试"
    }
}
