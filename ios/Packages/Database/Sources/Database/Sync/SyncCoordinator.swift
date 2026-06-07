import Foundation

/// Pulls Family / Member / Baby snapshots from network APIs and merges into local GRDB caches.
public actor SyncCoordinator {
    public static let sharedEventStreamCapacity = 16

    private let familyRepository: any FamilyRepository
    private let membershipRepository: any MembershipRepository
    private let babyRepository: any BabyRepository
    private let settingRepository: any SettingRepository
    private let syncProvider: any FamilyMemberBabySyncProviding
    private let now: @Sendable () -> Int64

    private var continuation: AsyncStream<SyncEvent>.Continuation?
    public private(set) var events: AsyncStream<SyncEvent>

    public init(
        familyRepository: any FamilyRepository,
        membershipRepository: any MembershipRepository,
        babyRepository: any BabyRepository,
        settingRepository: any SettingRepository,
        syncProvider: any FamilyMemberBabySyncProviding,
        now: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970) }
    ) {
        self.familyRepository = familyRepository
        self.membershipRepository = membershipRepository
        self.babyRepository = babyRepository
        self.settingRepository = settingRepository
        self.syncProvider = syncProvider
        self.now = now

        var capturedContinuation: AsyncStream<SyncEvent>.Continuation?
        self.events = AsyncStream(bufferingPolicy: .bufferingNewest(Self.sharedEventStreamCapacity)) { continuation in
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation
    }

    deinit {
        continuation?.finish()
    }

    /// Incremental pull: fetch remote snapshots, merge with `updatedAt` LWW, prune removed rows.
    @discardableResult
    public func pullIncremental() async throws -> SyncResult {
        continuation?.yield(.started)

        do {
            let syncedAt = now()
            var familiesApplied = 0
            var membersApplied = 0
            var babiesApplied = 0

            let remoteFamilies = try await syncProvider.fetchFamilies()
            var familyIDs = Set<String>()

            for remote in remoteFamilies {
                familyIDs.insert(remote.id)
                let record = FamilyRecord(
                    id: remote.id,
                    name: remote.name,
                    myRole: remote.myRole,
                    updatedAt: remote.updatedAt
                )
                if try await familyRepository.saveIfNewer(record) {
                    familiesApplied += 1
                }
            }
            try await familyRepository.deleteAllExcept(ids: familyIDs)

            for familyId in familyIDs {
                let remoteMembers = try await syncProvider.fetchMembers(familyId: familyId)
                var memberUserIDs = Set<String>()
                for remote in remoteMembers {
                    memberUserIDs.insert(remote.userId)
                    let record = MembershipRecord(
                        userId: remote.userId,
                        familyId: remote.familyId,
                        role: remote.role,
                        nickname: remote.nickname,
                        joinAt: remote.joinAt,
                        updatedAt: remote.updatedAt
                    )
                    if try await membershipRepository.saveIfNewer(record) {
                        membersApplied += 1
                    }
                }
                try await membershipRepository.deleteByFamilyExcept(familyId: familyId, userIds: memberUserIDs)

                let remoteBabies = try await syncProvider.fetchBabies(familyId: familyId)
                var babyIDs = Set<String>()
                for remote in remoteBabies {
                    babyIDs.insert(remote.id)
                    if try await babyRepository.saveIfNewer(remote.toRecord()) {
                        babiesApplied += 1
                    }
                }
                try await babyRepository.deleteByFamilyExcept(familyId: familyId, ids: babyIDs)
            }

            try await SyncCursor.write(syncedAt, to: settingRepository)
            let result = SyncResult(
                familiesApplied: familiesApplied,
                membersApplied: membersApplied,
                babiesApplied: babiesApplied,
                syncedAt: syncedAt
            )
            continuation?.yield(.completed(result))
            return result
        } catch {
            continuation?.yield(.failed(String(describing: error)))
            throw error
        }
    }

    public func lastSuccessfulSyncAt() async throws -> Int64 {
        try await SyncCursor.read(from: settingRepository)
    }
}
