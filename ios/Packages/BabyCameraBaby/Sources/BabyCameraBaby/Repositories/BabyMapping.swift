import BabyCameraNetwork
import Database
import Foundation

enum BabyMapping {
    static func profile(from data: BabyData, fallbackFamilyId: String? = nil) -> BabyProfile {
        BabyProfile(
            id: data.babyId,
            familyId: data.familyId ?? fallbackFamilyId ?? "",
            name: data.name,
            gender: BabyGender(apiValue: data.gender),
            birthDate: data.birthday,
            birthTime: data.birthTime,
            avatarURL: data.avatarUrl,
            updatedAt: Int64(Date().timeIntervalSince1970)
        )
    }

    static func createRequest(from profile: BabyProfile) -> CreateBabyRequest {
        CreateBabyRequest(
            name: profile.name.trimmingCharacters(in: .whitespacesAndNewlines),
            birthday: profile.birthDate,
            gender: profile.gender?.apiValue ?? "",
            birthTime: profile.birthTime
        )
    }

    static func updateRequest(from profile: BabyProfile) -> UpdateBabyRequest {
        UpdateBabyRequest(
            name: profile.name.trimmingCharacters(in: .whitespacesAndNewlines),
            birthday: profile.birthDate,
            gender: profile.gender?.apiValue,
            birthTime: profile.birthTime
        )
    }
}
