import Foundation
import XCTest
@testable import BabyCameraFamilyFeed

final class WechatOpenSDKConfigurationTests: XCTestCase {
    func testResolveModeStubWhenUseOpenSDKDisabled() {
        let bundle = makeBundle(
            info: [
                WechatOpenSDKConfiguration.useOpenSDKInfoPlistKey: "NO",
                WechatOpenSDKConfiguration.appIDInfoPlistKey: "wxstaging001",
                WechatOpenSDKConfiguration.universalLinkInfoPlistKey: "https://app.babycamera.cn/wechat/",
            ]
        )

        XCTAssertEqual(
            WechatOpenSDKConfiguration.resolveMode(bundle: bundle),
            .stub
        )
        XCTAssertEqual(
            WechatShareAdapterFactory.currentMode(bundle: bundle),
            .stub
        )
    }

    func testResolveModeStubWhenForceStub() {
        let bundle = makeBundle(
            info: [WechatOpenSDKConfiguration.useOpenSDKInfoPlistKey: "YES"]
        )

        XCTAssertEqual(
            WechatOpenSDKConfiguration.resolveMode(bundle: bundle, forceStub: true),
            .stub
        )
    }

    func testShareConfigurationReadsInfoPlist() {
        let bundle = makeBundle(
            info: [
                WechatOpenSDKConfiguration.appIDInfoPlistKey: "wxtest123",
                WechatOpenSDKConfiguration.universalLinkInfoPlistKey: "https://staging.example.com/wechat/",
            ]
        )

        let configuration = WechatOpenSDKConfiguration.shareConfiguration(bundle: bundle)
        XCTAssertEqual(configuration.appID, "wxtest123")
        XCTAssertEqual(configuration.universalLink, "https://staging.example.com/wechat/")
    }

    func testFactoryBuildsStubBridgeWhenDisabled() {
        let bundle = makeBundle(
            info: [WechatOpenSDKConfiguration.useOpenSDKInfoPlistKey: "NO"]
        )

        _ = WechatShareAdapterFactory.make(bundle: bundle)
        XCTAssertEqual(WechatShareAdapterFactory.currentMode(bundle: bundle), .stub)
    }

    func testParseBoolTreatsUnresolvedBuildSettingAsDefault() {
        let bundle = makeBundle(
            info: [WechatOpenSDKConfiguration.useOpenSDKInfoPlistKey: "$(WECHAT_USE_OPENSDK)"]
        )

        XCTAssertEqual(
            WechatOpenSDKConfiguration.resolveMode(bundle: bundle),
            .stub
        )
    }

    private func makeBundle(info: [String: String]) -> Bundle {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WechatConfig-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let plistURL = directory.appendingPathComponent("Info.plist")
        let plist: [String: Any] = info
        let data = try! PropertyListSerialization.data(fromPropertyList: plist, format: .xml, formatOptions: 0)
        try! data.write(to: plistURL)

        return Bundle(url: directory)!
    }
}
