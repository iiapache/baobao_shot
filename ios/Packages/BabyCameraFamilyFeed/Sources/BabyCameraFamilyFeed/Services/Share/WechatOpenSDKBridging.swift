import Foundation

/// 微信 OpenSDK 桥接协议；生产环境由宿主 App 注入真实 WXApi 实现（T5.13）。
public protocol WechatOpenSDKBridging: Sendable {
    var isWechatInstalled: Bool { get }
    func send(_ payload: WechatSharePayload) async throws
}

/// Stub 桥接：不调用真实 OpenSDK，用于单测与未集成 SDK 时的编译占位。
public struct StubWechatOpenSDKBridge: WechatOpenSDKBridging {
    public let isWechatInstalled: Bool

    public init(isWechatInstalled: Bool = true) {
        self.isWechatInstalled = isWechatInstalled
    }

    public func send(_ payload: WechatSharePayload) async throws {
        _ = payload
    }
}
