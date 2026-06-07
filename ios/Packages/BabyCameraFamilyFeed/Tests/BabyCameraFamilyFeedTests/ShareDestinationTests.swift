import XCTest
@testable import BabyCameraFamilyFeed

final class ShareDestinationTests: XCTestCase {
    func testSocialDestinationsUseSystemShareSheet() {
        for destination in ShareDestination.allCases {
            XCTAssertTrue(destination.usesSystemShareSheet)
        }
    }

    func testDisplayNames() {
        XCTAssertEqual(ShareDestination.system.displayName, "系统分享")
        XCTAssertEqual(ShareDestination.xiaohongshu.displayName, "小红书")
        XCTAssertEqual(ShareDestination.douyin.displayName, "抖音")
    }
}
