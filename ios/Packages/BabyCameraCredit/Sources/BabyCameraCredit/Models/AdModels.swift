import BabyCameraNetwork
import Foundation

/// 广告位类型（T4.15 / PRD §4.11.5）。
public enum AdPlacement: String, Sendable, CaseIterable, Codable {
    case splash
    case interstitial
    case rewarded
}

/// 广告联盟网络。
public enum AdNetwork: String, Sendable, CaseIterable, Codable {
    case pangle
    case gdt
    case admob

    /// 与 credit-sub-ad-svc `NormalizeNetwork` 对齐的上报值。
    public var reportValue: String { rawValue }
}

public struct AdPlacementConfig: Sendable, Equatable {
    public let placementID: String

    public init(placementID: String) {
        self.placementID = placementID
    }
}

/// 各广告位单元 ID 配置（生产由远端/CI 注入，测试用 stub）。
public struct AdUnitIDs: Sendable, Equatable {
    public let splash: AdPlacementConfig
    public let interstitial: AdPlacementConfig
    public let rewarded: AdPlacementConfig

    public init(
        splash: AdPlacementConfig,
        interstitial: AdPlacementConfig,
        rewarded: AdPlacementConfig
    ) {
        self.splash = splash
        self.interstitial = interstitial
        self.rewarded = rewarded
    }

    public func config(for placement: AdPlacement) -> AdPlacementConfig {
        switch placement {
        case .splash:
            return splash
        case .interstitial:
            return interstitial
        case .rewarded:
            return rewarded
        }
    }

    public static func stub(region: AppRegion) -> AdUnitIDs {
        switch region {
        case .cn:
            return AdUnitIDs(
                splash: AdPlacementConfig(placementID: "pangle_splash_stub"),
                interstitial: AdPlacementConfig(placementID: "pangle_interstitial_stub"),
                rewarded: AdPlacementConfig(placementID: "pangle_rewarded_stub")
            )
        case .os:
            return AdUnitIDs(
                splash: AdPlacementConfig(placementID: "admob_splash_stub"),
                interstitial: AdPlacementConfig(placementID: "admob_interstitial_stub"),
                rewarded: AdPlacementConfig(placementID: "admob_rewarded_stub")
            )
        }
    }
}

/// SDK 加载后的可展示素材句柄。
public struct AdCreative: Sendable, Equatable {
    public let network: AdNetwork
    public let placement: AdPlacement
    public let placementID: String
    public let transactionID: String

    public init(
        network: AdNetwork,
        placement: AdPlacement,
        placementID: String,
        transactionID: String
    ) {
        self.network = network
        self.placement = placement
        self.placementID = placementID
        self.transactionID = transactionID
    }
}

public enum AdShowResult: Sendable, Equatable {
    case rewarded(transactionID: String)
    case impressed(transactionID: String)
    case dismissed
    case failed(String)
}

public struct AdRewardGrant: Sendable, Equatable {
    public let grantedCredits: Int
    public let balanceAfter: Int
    public let ledgerID: String
    public let duplicate: Bool

    public init(
        grantedCredits: Int,
        balanceAfter: Int,
        ledgerID: String,
        duplicate: Bool = false
    ) {
        self.grantedCredits = grantedCredits
        self.balanceAfter = balanceAfter
        self.ledgerID = ledgerID
        self.duplicate = duplicate
    }
}

public enum AdSkipReason: String, Sendable, Equatable {
    case subscribed
    case frequencyLimitReached
    case interstitialNotSampled
    case sdkUnavailable
    case loadFailed
    case showFailed
    case userDismissed
}

public enum AdManagerOutcome: Sendable, Equatable {
    case shown(network: AdNetwork, placement: AdPlacement, transactionID: String)
    case skipped(AdSkipReason)
}

public struct AdRewardOutcome: Sendable, Equatable {
    public let network: AdNetwork
    public let transactionID: String
    public let grant: AdRewardGrant

    public init(network: AdNetwork, transactionID: String, grant: AdRewardGrant) {
        self.network = network
        self.transactionID = transactionID
        self.grant = grant
    }
}

public enum AdManagerError: Error, Equatable, Sendable {
    case notAuthenticated
    case sdkUnavailable
    case loadFailed(String)
    case showFailed(String)
    case rewardNotEarned
    case reportFailed(String)
}
