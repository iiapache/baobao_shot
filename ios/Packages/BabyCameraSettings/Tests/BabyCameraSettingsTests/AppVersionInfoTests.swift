import XCTest
@testable import BabyCameraSettings

final class AppVersionInfoTests: XCTestCase {
    func testDisplayStringIncludesBuildNumber() {
        let info = AppVersionInfo(marketingVersion: "1.0.0", buildNumber: "42")
        XCTAssertEqual(info.displayString, "1.0.0 (42)")
    }

    func testDisplayStringOmitsEmptyBuild() {
        let info = AppVersionInfo(marketingVersion: "2.0.0", buildNumber: "")
        XCTAssertEqual(info.displayString, "2.0.0")
    }
}
