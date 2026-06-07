import Database
import Foundation

public struct BabyProfile: Identifiable, Equatable, Sendable, Codable {
    public var id: String
    public var familyId: String
    public var name: String
    public var gender: BabyGender?
    public var birthDate: String
    public var birthTime: String?
    public var avatarURL: String?
    public var updatedAt: Int64

    public init(
        id: String,
        familyId: String,
        name: String,
        gender: BabyGender? = nil,
        birthDate: String,
        birthTime: String? = nil,
        avatarURL: String? = nil,
        updatedAt: Int64 = 0
    ) {
        self.id = id
        self.familyId = familyId
        self.name = name
        self.gender = gender
        self.birthDate = birthDate
        self.birthTime = birthTime
        self.avatarURL = avatarURL
        self.updatedAt = updatedAt
    }

    public init(record: BabyRecord) {
        self.id = record.id
        self.familyId = record.familyId
        self.name = record.name
        self.gender = record.gender.map { BabyGender(apiValue: $0) }
        self.birthDate = record.birthDate
        self.birthTime = record.birthTime
        self.avatarURL = record.avatarPath
        self.updatedAt = record.updatedAt
    }

    public func toRecord() -> BabyRecord {
        BabyRecord(
            id: id,
            familyId: familyId,
            name: name,
            gender: gender?.apiValue.nilIfEmpty,
            birthDate: birthDate,
            birthTime: birthTime,
            avatarPath: avatarURL,
            updatedAt: updatedAt
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
