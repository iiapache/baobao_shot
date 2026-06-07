import Foundation

/// 广告联盟 SDK 抽象（穿山甲 / 优量汇 / AdMob 真实 SDK 的替换点）。
public protocol AdSDKClient: Sendable {
    var network: AdNetwork { get }

    func initialize() async throws
    func load(placement: AdPlacement, placementID: String) async throws -> AdCreative
    func show(_ creative: AdCreative) async throws -> AdShowResult
}
