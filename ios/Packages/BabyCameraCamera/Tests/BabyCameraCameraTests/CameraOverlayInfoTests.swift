import BabyCameraBaby
import XCTest
@testable import BabyCameraCamera

final class CameraOverlayInfoTests: XCTestCase {
    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        referenceDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 20))!
    }

    func testInitFromBabyProfileUsesBabyAgeFormatter() {
        let baby = BabyProfile(
            id: "bb_1",
            familyId: "fam",
            name: "豆豆",
            birthDate: "2024-01-15"
        )

        let info = CameraOverlayInfo(baby: baby, referenceDate: referenceDate)

        XCTAssertEqual(info.babyId, "bb_1")
        XCTAssertEqual(info.babyName, "豆豆")
        XCTAssertEqual(info.birthDate, "2024-01-15")
        XCTAssertEqual(info.displayAge, "出生第 6 天")
        XCTAssertEqual(info.ageDay, 6)
    }

    func testInitFromBabyProfileAtHundredDayBoundary() {
        let baby = BabyProfile(
            id: "bb_2",
            familyId: "fam",
            name: "糖糖",
            birthDate: "2024-01-01"
        )
        let day100 = calendar.date(from: DateComponents(year: 2024, month: 4, day: 9))!

        let info = CameraOverlayInfo(baby: baby, referenceDate: day100)

        XCTAssertEqual(info.displayAge, "3 个月 8 天")
        XCTAssertEqual(info.ageDay, 100)
    }

    func testCodableRoundTrip() throws {
        let original = CameraOverlayInfo(
            babyId: "bb_1",
            babyName: "豆豆",
            birthDate: "2024-01-15",
            displayAge: "出生第 6 天",
            ageDay: 6
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CameraOverlayInfo.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
