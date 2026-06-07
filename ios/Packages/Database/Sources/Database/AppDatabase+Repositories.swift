import GRDB

public extension AppDatabase {
    func makeFamilyRepository() -> GRDBFamilyRepository {
        GRDBFamilyRepository(dbWriter: dbWriter)
    }

    func makeMembershipRepository() -> GRDBMembershipRepository {
        GRDBMembershipRepository(dbWriter: dbWriter)
    }

    func makeBabyRepository() -> GRDBBabyRepository {
        GRDBBabyRepository(dbWriter: dbWriter)
    }

    func makePhotoRepository() -> GRDBPhotoRepository {
        GRDBPhotoRepository(dbWriter: dbWriter)
    }

    func makeSettingRepository() -> GRDBSettingRepository {
        GRDBSettingRepository(dbWriter: dbWriter)
    }

    func makeMilestoneRepository() -> GRDBMilestoneRepository {
        GRDBMilestoneRepository(dbWriter: dbWriter)
    }

    func makeAITaskLocalRepository() -> GRDBAITaskLocalRepository {
        GRDBAITaskLocalRepository(dbWriter: dbWriter)
    }

    func makeDerivedRepository() -> GRDBDerivedRepository {
        GRDBDerivedRepository(dbWriter: dbWriter)
    }

    func makeFeedCacheRepository() -> GRDBFeedCacheRepository {
        GRDBFeedCacheRepository(dbWriter: dbWriter)
    }

    func makeSyncCoordinator(syncProvider: any FamilyMemberBabySyncProviding) -> SyncCoordinator {
        SyncCoordinator(
            familyRepository: makeFamilyRepository(),
            membershipRepository: makeMembershipRepository(),
            babyRepository: makeBabyRepository(),
            settingRepository: makeSettingRepository(),
            syncProvider: syncProvider
        )
    }
}
