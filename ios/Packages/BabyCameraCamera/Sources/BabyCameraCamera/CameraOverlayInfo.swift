import BabyCameraBaby
import Foundation

/// 取景框信息浮层数据（宝宝小名 + 成长天数），供预览 Overlay 与元数据 / 水印 hook 共用。
public struct CameraOverlayInfo: Equatable, Sendable, Codable {
    public let babyId: String
    public let babyName: String
    public let birthDate: String
    public let displayAge: String
    /// 出生第 N 天（PRD §4.2.3），供 MetadataWriter / 水印 hook 使用。
    public let ageDay: Int

    public init(
        babyId: String,
        babyName: String,
        birthDate: String,
        displayAge: String,
        ageDay: Int
    ) {
        self.babyId = babyId
        self.babyName = babyName
        self.birthDate = birthDate
        self.displayAge = displayAge
        self.ageDay = ageDay
    }

    public init(baby: BabyProfile, referenceDate: Date = Date()) {
        self.babyId = baby.id
        self.babyName = baby.name
        self.birthDate = baby.birthDate
        self.displayAge = BabyAgeFormatter.displayAge(
            birthDate: baby.birthDate,
            referenceDate: referenceDate
        )
        self.ageDay = GrowthDayCalculator.growthDay(
            birthDate: baby.birthDate,
            takenAt: referenceDate
        ) ?? 0
    }
}
