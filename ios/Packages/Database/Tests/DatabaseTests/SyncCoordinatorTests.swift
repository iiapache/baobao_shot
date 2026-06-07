import XCTest
@testable import Database

final class SyncCoordinatorTests: XCTestCase {
    func testOfflineReadUsesLocalCache() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let familyRepository = appDatabase.makeFamilyRepository()
        let babyRepository = appDatabase.makeBabyRepository()

        try await familyRepository.save(
            FamilyRecord(id: "fam_1", name: "离线家庭", myRole: "admin", updatedAt: 100)
        )
        try await babyRepository.save(
            BabyRecord(
                id: "baby_1",
                familyId: "fam_1",
                name: "离线宝宝",
                birthDate: "2024-01-01",
                updatedAt: 100
            )
        )

        let families = try await familyRepository.fetchAll()
        let babies = try await babyRepository.fetchAll(familyId: "fam_1")

        XCTAssertEqual(families.map(\.name), ["离线家庭"])
        XCTAssertEqual(babies.map(\.name), ["离线宝宝"])
    }

    func testPullIncrementalAppliesRemoteAndPrunesRemovedRows() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let coordinator = makeCoordinator(database: appDatabase, provider: MockSyncProvider(
            families: [
                RemoteFamilySnapshot(id: "fam_1", name: "云端家庭", myRole: "admin", updatedAt: 200),
            ],
            members: [
                RemoteMemberSnapshot(
                    userId: "user_2",
                    familyId: "fam_1",
                    role: "family",
                    nickname: "爸爸",
                    joinAt: 150,
                    updatedAt: 150
                ),
            ],
            babies: [
                RemoteBabySnapshot(
                    id: "baby_2",
                    familyId: "fam_1",
                    name: "云端宝宝",
                    birthDate: "2024-02-01",
                    updatedAt: 200
                ),
            ]
        ), now: { 300 })

        let familyRepository = appDatabase.makeFamilyRepository()
        let membershipRepository = appDatabase.makeMembershipRepository()
        let babyRepository = appDatabase.makeBabyRepository()

        try await familyRepository.save(
            FamilyRecord(id: "fam_old", name: "过期家庭", myRole: "admin", updatedAt: 50)
        )
        try await membershipRepository.save(
            MembershipRecord(userId: "user_1", familyId: "fam_1", role: "admin", joinAt: 100, updatedAt: 100)
        )
        try await babyRepository.save(
            BabyRecord(id: "baby_old", familyId: "fam_1", name: "过期宝宝", birthDate: "2023-01-01", updatedAt: 50)
        )

        let result = try await coordinator.pullIncremental()

        XCTAssertEqual(result.familiesApplied, 1)
        XCTAssertEqual(result.membersApplied, 1)
        XCTAssertEqual(result.babiesApplied, 1)
        XCTAssertEqual(try await coordinator.lastSuccessfulSyncAt(), 300)

        let families = try await familyRepository.fetchAll()
        XCTAssertEqual(families.map(\.id), ["fam_1"])
        XCTAssertEqual(families.first?.name, "云端家庭")

        let members = try await membershipRepository.fetchByFamily(familyId: "fam_1")
        XCTAssertEqual(members.map(\.userId), ["user_2"])

        let babies = try await babyRepository.fetchAll(familyId: "fam_1")
        XCTAssertEqual(babies.map(\.id), ["baby_2"])
    }

    func testConflictResolutionKeepsNewerUpdatedAt() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let babyRepository = appDatabase.makeBabyRepository()

        try await babyRepository.save(
            BabyRecord(
                id: "baby_1",
                familyId: "fam_1",
                name: "本地较新",
                birthDate: "2024-01-01",
                updatedAt: 500
            )
        )

        let coordinator = makeCoordinator(database: appDatabase, provider: MockSyncProvider(
            families: [
                RemoteFamilySnapshot(id: "fam_1", name: "家庭", myRole: "admin", updatedAt: 100),
            ],
            members: [],
            babies: [
                RemoteBabySnapshot(
                    id: "baby_1",
                    familyId: "fam_1",
                    name: "远端较旧",
                    birthDate: "2024-01-01",
                    updatedAt: 100
                ),
            ]
        ))

        _ = try await coordinator.pullIncremental()

        let baby = try await babyRepository.fetch(id: "baby_1")
        XCTAssertEqual(baby?.name, "本地较新")
        XCTAssertEqual(baby?.updatedAt, 500)
    }

    func testConflictResolutionAppliesNewerRemote() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let babyRepository = appDatabase.makeBabyRepository()

        try await babyRepository.save(
            BabyRecord(
                id: "baby_1",
                familyId: "fam_1",
                name: "本地较旧",
                birthDate: "2024-01-01",
                updatedAt: 100
            )
        )

        let coordinator = makeCoordinator(database: appDatabase, provider: MockSyncProvider(
            families: [
                RemoteFamilySnapshot(id: "fam_1", name: "家庭", myRole: "admin", updatedAt: 100),
            ],
            members: [],
            babies: [
                RemoteBabySnapshot(
                    id: "baby_1",
                    familyId: "fam_1",
                    name: "远端较新",
                    birthDate: "2024-01-01",
                    updatedAt: 500
                ),
            ]
        ))

        _ = try await coordinator.pullIncremental()

        let baby = try await babyRepository.fetch(id: "baby_1")
        XCTAssertEqual(baby?.name, "远端较新")
        XCTAssertEqual(baby?.updatedAt, 500)
    }

    func testSyncMergeUnitCases() {
        XCTAssertTrue(SyncMerge.shouldApplyRemote(localUpdatedAt: nil, remoteUpdatedAt: 1))
        XCTAssertTrue(SyncMerge.shouldApplyRemote(localUpdatedAt: 100, remoteUpdatedAt: 100))
        XCTAssertTrue(SyncMerge.shouldApplyRemote(localUpdatedAt: 100, remoteUpdatedAt: 200))
        XCTAssertFalse(SyncMerge.shouldApplyRemote(localUpdatedAt: 200, remoteUpdatedAt: 100))
    }

    private func makeCoordinator(
        database: AppDatabase,
        provider: MockSyncProvider,
        now: @escaping @Sendable () -> Int64 = { 1_000 }
    ) -> SyncCoordinator {
        SyncCoordinator(
            familyRepository: database.makeFamilyRepository(),
            membershipRepository: database.makeMembershipRepository(),
            babyRepository: database.makeBabyRepository(),
            settingRepository: database.makeSettingRepository(),
            syncProvider: provider,
            now: now
        )
    }
}

private struct MockSyncProvider: FamilyMemberBabySyncProviding {
    let families: [RemoteFamilySnapshot]
    let members: [RemoteMemberSnapshot]
    let babies: [RemoteBabySnapshot]

    func fetchFamilies() async throws -> [RemoteFamilySnapshot] { families }

    func fetchMembers(familyId: String) async throws -> [RemoteMemberSnapshot] {
        members.filter { $0.familyId == familyId }
    }

    func fetchBabies(familyId: String) async throws -> [RemoteBabySnapshot] {
        babies.filter { $0.familyId == familyId }
    }
}
