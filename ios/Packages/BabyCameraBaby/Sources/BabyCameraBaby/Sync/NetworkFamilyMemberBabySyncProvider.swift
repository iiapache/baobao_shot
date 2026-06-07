import BabyCameraNetwork
import Database
import Foundation

/// Bridges `FamilyAPI` / `BabyAPI` to `FamilyMemberBabySyncProviding` for `SyncCoordinator`.
public struct NetworkFamilyMemberBabySyncProvider: FamilyMemberBabySyncProviding, Sendable {
    private let familyAPI: FamilyAPI
    private let babyAPI: BabyAPI
    private let now: @Sendable () -> Int64

    public init(
        familyAPI: FamilyAPI,
        babyAPI: BabyAPI,
        now: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970) }
    ) {
        self.familyAPI = familyAPI
        self.babyAPI = babyAPI
        self.now = now
    }

    public init(client: APIClient, now: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970) }) {
        self.init(familyAPI: FamilyAPI(client: client), babyAPI: BabyAPI(client: client), now: now)
    }

    public func fetchFamilies() async throws -> [RemoteFamilySnapshot] {
        let items = try await familyAPI.listFamilies().items
        let syncedAt = now()
        return items.map {
            RemoteFamilySnapshot(
                id: $0.familyId,
                name: $0.name,
                myRole: $0.role,
                updatedAt: syncedAt
            )
        }
    }

    public func fetchMembers(familyId: String) async throws -> [RemoteMemberSnapshot] {
        let items = try await familyAPI.listMembers(familyId: familyId).items
        return items.map { member in
            let joinAt = ISO8601Timestamp.unixSeconds(from: member.joinedAt, fallback: now())
            return RemoteMemberSnapshot(
                userId: member.userId,
                familyId: familyId,
                role: member.role,
                nickname: member.nickname,
                joinAt: joinAt,
                updatedAt: joinAt
            )
        }
    }

    public func fetchBabies(familyId: String) async throws -> [RemoteBabySnapshot] {
        let items = try await babyAPI.listByFamily(familyId: familyId).items
        let syncedAt = now()
        return items.map { baby in
            RemoteBabySnapshot(
                id: baby.babyId,
                familyId: baby.familyId ?? familyId,
                name: baby.name,
                gender: baby.gender,
                birthDate: baby.birthday,
                birthTime: baby.birthTime,
                avatarPath: baby.avatarUrl,
                updatedAt: syncedAt
            )
        }
    }
}
