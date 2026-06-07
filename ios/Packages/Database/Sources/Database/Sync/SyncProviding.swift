import Foundation

/// Network-facing sync contract for Family / Member / Baby pull (mocked in unit tests).
public protocol FamilyMemberBabySyncProviding: Sendable {
    func fetchFamilies() async throws -> [RemoteFamilySnapshot]
    func fetchMembers(familyId: String) async throws -> [RemoteMemberSnapshot]
    func fetchBabies(familyId: String) async throws -> [RemoteBabySnapshot]
}
