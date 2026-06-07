import BabyCameraBaby
import Database
import Foundation

enum MainTabBabyLoaderError: LocalizedError {
    case missingFamily

    var errorDescription: String? {
        switch self {
        case .missingFamily:
            return "未找到家庭，请先完成新手引导或加入家庭"
        }
    }
}

/// 从本地 DB 同步宝宝列表到 `CurrentBabyEnvironment`。
enum MainTabBabyLoader {
    static func resolvePrimaryFamilyId(database: AppDatabase) async throws -> String {
        let familyRepository = database.makeFamilyRepository()
        let localFamilies = try await familyRepository.fetchAll()
        if let first = localFamilies.first {
            return first.id
        }

        let babyRepository = database.makeBabyRepository()
        if let babyId = UserDefaults.standard.string(forKey: "com.babycamera.currentBabyId"),
           let baby = try await babyRepository.fetch(id: babyId),
           !baby.familyId.isEmpty {
            return baby.familyId
        }

        throw MainTabBabyLoaderError.missingFamily
    }

    static func load(into store: CurrentBabyEnvironment, database: AppDatabase) async {
        do {
            let familyRepository = database.makeFamilyRepository()
            let babyRepository = database.makeBabyRepository()
            let families = try await familyRepository.fetchAll()
            var profiles: [BabyProfile] = []
            for family in families {
                let records = try await babyRepository.fetchAll(familyId: family.id)
                profiles.append(contentsOf: records.map(BabyProfile.init(record:)))
            }
            guard !profiles.isEmpty else { return }
            store.replaceBabies(profiles)
        } catch {
            // 离线或尚未同步时保留 onboarding 已注入的宝宝。
        }
    }
}
