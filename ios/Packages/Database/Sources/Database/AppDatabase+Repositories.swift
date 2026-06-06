import GRDB

public extension AppDatabase {
    func makeBabyRepository() -> GRDBBabyRepository {
        GRDBBabyRepository(dbWriter: dbWriter)
    }

    func makePhotoRepository() -> GRDBPhotoRepository {
        GRDBPhotoRepository(dbWriter: dbWriter)
    }

    func makeSettingRepository() -> GRDBSettingRepository {
        GRDBSettingRepository(dbWriter: dbWriter)
    }
}
