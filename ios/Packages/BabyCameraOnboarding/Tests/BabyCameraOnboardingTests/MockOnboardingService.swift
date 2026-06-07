import BabyCameraBaby
import BabyCameraFamily
import BabyCameraNetwork
import Foundation

final class InMemoryOnboardingProgressStore: OnboardingProgressStoring, @unchecked Sendable {
    private var completedUserIds: Set<String> = []

    func hasCompleted(userId: String) -> Bool {
        completedUserIds.contains(userId)
    }

    func markCompleted(userId: String) {
        completedUserIds.insert(userId)
    }

    func reset(userId: String) {
        completedUserIds.remove(userId)
    }
}

final class MockOnboardingService: OnboardingServing, @unchecked Sendable {
    var updateProfileCalls: [String] = []
    var consentCalls: [(String, Bool)] = []
    var createFamilyCalls: [String] = []
    var joinCalls: [(String, FamilyRelation, String?)] = []
    var createBabyCalls: [(String, BabyProfile)] = []
    var refreshCount = 0

    var updateProfileResult = AccountMeData(
        userId: "usr_test_001",
        nickname: "豆豆妈",
        avatarUrl: nil,
        region: "cn",
        consents: UserConsents(childData: false)
    )
    var refreshResult = AccountMeData(
        userId: "usr_test_001",
        nickname: "豆豆妈",
        avatarUrl: nil,
        region: "cn",
        consents: UserConsents(childData: true)
    )
    var createFamilyResult = FamilySummary(id: "fam_new_001", name: "新家", role: .admin)
    var joinFamilyResult = JoinFamilyResult(
        familyId: "fam_join_001",
        role: .family,
        joinedAt: "2026-06-06T10:00:00Z"
    )
    var createBabyResult = BabyProfile(
        id: "bb_new_001",
        familyId: "fam_new_001",
        name: "糖糖",
        birthDate: "2024-01-01"
    )

    func updateProfile(nickname: String) async throws -> AccountMeData {
        updateProfileCalls.append(nickname)
        return AccountMeData(
            userId: updateProfileResult.userId,
            nickname: nickname,
            avatarUrl: updateProfileResult.avatarUrl,
            region: updateProfileResult.region,
            consents: updateProfileResult.consents
        )
    }

    func submitChildDataConsent(version: String, accepted: Bool) async throws -> ChildDataConsentData {
        consentCalls.append((version, accepted))
        return ChildDataConsentData(version: version, agreedAt: "2026-06-06T10:00:00Z")
    }

    func createFamily(name: String) async throws -> FamilySummary {
        createFamilyCalls.append(name)
        return FamilySummary(
            id: createFamilyResult.id,
            name: name,
            role: createFamilyResult.role
        )
    }

    func joinFamily(
        code: String,
        relation: FamilyRelation,
        nickname: String?
    ) async throws -> JoinFamilyResult {
        joinCalls.append((code, relation, nickname))
        return joinFamilyResult
    }

    func joinFamily(
        fromScannedContent: String,
        relation: FamilyRelation,
        nickname: String?
    ) async throws -> JoinFamilyResult {
        joinCalls.append((fromScannedContent, relation, nickname))
        return joinFamilyResult
    }

    func createBaby(familyId: String, profile: BabyProfile) async throws -> BabyProfile {
        createBabyCalls.append((familyId, profile))
        return BabyProfile(
            id: createBabyResult.id,
            familyId: familyId,
            name: profile.name,
            gender: profile.gender,
            birthDate: profile.birthDate,
            birthTime: profile.birthTime
        )
    }

    func refreshProfile() async throws -> AccountMeData {
        refreshCount += 1
        return refreshResult
    }

    func extractInviteCode(from content: String) throws -> String {
        if content.contains("888888") {
            return "888888"
        }
        return content
    }
}
