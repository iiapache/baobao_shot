import Foundation

public protocol FamilyServing: Sendable {
    func listFamilies() async throws -> [FamilySummary]
    func createFamily(name: String) async throws -> FamilySummary
    func getFamily(familyId: String) async throws -> FamilyDetail
    func updateFamily(familyId: String, name: String) async throws -> FamilySummary
    func deleteFamily(familyId: String) async throws
    func listMembers(familyId: String) async throws -> [FamilyMember]
    func updateMember(
        familyId: String,
        userId: String,
        role: FamilyRole?,
        nickname: String?
    ) async throws -> FamilyMember
    func removeMember(familyId: String, userId: String) async throws
    func createInvitation(familyId: String) async throws -> FamilyInvitation
    func revokeInvitation(familyId: String, code: String) async throws
    func joinFamily(code: String, relation: FamilyRelation, nickname: String?) async throws -> JoinFamilyResult
    func joinFamily(fromScannedContent scanned: String, relation: FamilyRelation, nickname: String?) async throws -> JoinFamilyResult
    func transferAdmin(familyId: String, targetUserId: String) async throws -> TransferAdminResult
    func takeover(familyId: String, choice: TakeoverBallotChoice?) async throws -> TakeoverVoteResult
}

extension FamilyService: FamilyServing {}
