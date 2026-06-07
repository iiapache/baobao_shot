import Foundation

/// 真实联盟 SDK 适配入口。未链接 SDK 时回退 Staging Bridge，保证 CI / 模拟器可编译。
public enum LiveAdSDKFactory {
    public static func makeCNClients() -> [AdSDKClient] {
        #if BABYCAMERA_AD_SDK_LIVE
        return [
            PangleAdSDKClient(),
            GDTAdSDKClient(),
        ]
        #else
        return StagingBridgeAdSDKFactory.makeCNClients()
        #endif
    }

    public static func makeOSClients() -> [AdSDKClient] {
        #if BABYCAMERA_AD_SDK_LIVE
        return [AdMobAdSDKClient()]
        #else
        return StagingBridgeAdSDKFactory.makeOSClients()
        #endif
    }
}

#if BABYCAMERA_AD_SDK_LIVE
// 链接穿山甲 / 优量汇 / AdMob 后在此实现 PangleAdSDKClient / GDTAdSDKClient / AdMobAdSDKClient。
// 执行 ios/ThirdParty/enable-ad-sdks.sh 后补充具体 SDK 调用。
public struct PangleAdSDKClient: AdSDKClient, @unchecked Sendable {
    public let network: AdNetwork = .pangle

    public func initialize() async throws {
        throw AdManagerError.sdkUnavailable
    }

    public func load(placement: AdPlacement, placementID: String) async throws -> AdCreative {
        throw AdManagerError.sdkUnavailable
    }

    public func show(_ creative: AdCreative) async throws -> AdShowResult {
        throw AdManagerError.sdkUnavailable
    }
}

public struct GDTAdSDKClient: AdSDKClient, @unchecked Sendable {
    public let network: AdNetwork = .gdt

    public func initialize() async throws {
        throw AdManagerError.sdkUnavailable
    }

    public func load(placement: AdPlacement, placementID: String) async throws -> AdCreative {
        throw AdManagerError.sdkUnavailable
    }

    public func show(_ creative: AdCreative) async throws -> AdShowResult {
        throw AdManagerError.sdkUnavailable
    }
}

public struct AdMobAdSDKClient: AdSDKClient, @unchecked Sendable {
    public let network: AdNetwork = .admob

    public func initialize() async throws {
        throw AdManagerError.sdkUnavailable
    }

    public func load(placement: AdPlacement, placementID: String) async throws -> AdCreative {
        throw AdManagerError.sdkUnavailable
    }

    public func show(_ creative: AdCreative) async throws -> AdShowResult {
        throw AdManagerError.sdkUnavailable
    }
}
#endif
