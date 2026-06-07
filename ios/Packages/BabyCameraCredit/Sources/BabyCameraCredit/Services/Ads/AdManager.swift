import BabyCameraNetwork
import Foundation

public struct AdManagerConfiguration: Sendable {
    public let region: AppRegion
    public let regionConfig: RegionConfig
    public let tokenStore: TokenStore
    public let session: URLSession
    public let unitIDs: AdUnitIDs
    public let frequencyLimits: AdFrequencyLimits
    public let interstitialSampleRate: Double
    public let isSubscribed: @Sendable () -> Bool
    public let idfvProvider: @Sendable () -> String
    public let now: @Sendable () -> Date
    public let nonceFactory: @Sendable () -> String
    public let timestampFactory: @Sendable () -> Int64

    public init(
        region: AppRegion = .cn,
        regionConfig: RegionConfig? = nil,
        tokenStore: TokenStore = KeychainTokenStore(),
        session: URLSession = .shared,
        unitIDs: AdUnitIDs? = nil,
        frequencyLimits: AdFrequencyLimits = .default,
        interstitialSampleRate: Double = 0.5,
        isSubscribed: @escaping @Sendable () -> Bool = { false },
        idfvProvider: @escaping @Sendable () -> String = { "unknown-idfv" },
        now: @escaping @Sendable () -> Date = { Date() },
        nonceFactory: @escaping @Sendable () -> String = { UUID().uuidString },
        timestampFactory: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }
    ) {
        self.region = region
        self.regionConfig = regionConfig ?? RegionConfig(
            region: region,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            deviceId: AdManagerConfiguration.resolveDeviceId()
        )
        self.tokenStore = tokenStore
        self.session = session
        self.unitIDs = unitIDs ?? .stub(region: region)
        self.frequencyLimits = frequencyLimits
        self.interstitialSampleRate = min(1, max(0, interstitialSampleRate))
        self.isSubscribed = isSubscribed
        self.idfvProvider = idfvProvider
        self.now = now
        self.nonceFactory = nonceFactory
        self.timestampFactory = timestampFactory
    }

    private static func resolveDeviceId() -> String {
        let key = "com.babycamera.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}

/// 开屏 / 插页 / 激励统一调度；订阅用户自动跳过展示类广告。
@MainActor
public final class AdManager: ObservableObject {
    @Published public private(set) var lastOutcome: AdManagerOutcome?
    @Published public private(set) var isShowingAd = false

    private let configuration: AdManagerConfiguration
    private let aggregator: AdAggregator
    private let frequencyGate: AdFrequencyGate
    private let clientFactory: @Sendable (TokenStore) -> APIClient
    private var randomSource: @Sendable () -> Double
    private weak var creditService: CreditService?

    public init(
        configuration: AdManagerConfiguration = AdManagerConfiguration(),
        aggregator: AdAggregator? = nil,
        frequencyStore: AdFrequencyStoring = AdFrequencyStore(),
        clients: [any AdSDKClient]? = nil,
        clientFactory: (@Sendable (TokenStore) -> APIClient)? = nil,
        randomSource: @escaping @Sendable () -> Double = { Double.random(in: 0..<1) }
    ) {
        self.configuration = configuration
        self.aggregator = aggregator ?? AdAggregator.makeDefault(
            region: configuration.region,
            unitIDs: configuration.unitIDs,
            clients: clients
        )
        self.frequencyGate = AdFrequencyGate(
            store: frequencyStore,
            limits: configuration.frequencyLimits,
            now: configuration.now
        )
        self.clientFactory = clientFactory ?? { tokenStore in
            makeAuthenticatedClient(
                region: configuration.region,
                tokenStore: tokenStore,
                regionConfig: configuration.regionConfig,
                session: configuration.session
            )
        }
        self.randomSource = randomSource
    }

    public func bindCreditService(_ service: CreditService) {
        creditService = service
    }

    public func initializeSDKs() async {
        await aggregator.initializeAll()
    }

    /// 冷启动开屏：非订阅 + 当日首次。
    public func showSplashIfNeeded() async -> AdManagerOutcome {
        await showAutoPlacement(.splash)
    }

    /// 关闭编辑器等场景插页：非订阅 + 频次 + 抽样。
    public func showInterstitialIfNeeded() async -> AdManagerOutcome {
        guard !configuration.isSubscribed() else {
            return finish(.skipped(.subscribed))
        }
        guard frequencyGate.canShow(.interstitial) else {
            return finish(.skipped(.frequencyLimitReached))
        }
        guard randomSource() < configuration.interstitialSampleRate else {
            return finish(.skipped(.interstitialNotSampled))
        }
        return await present(.interstitial)
    }

    /// 激励视频：全量用户可主动触发，观看完毕上报入账。
    public func showRewardedAd() async throws -> AdRewardOutcome {
        isShowingAd = true
        defer { isShowingAd = false }

        let loaded = try await aggregator.loadAndShow(placement: .rewarded)
        switch loaded.result {
        case .rewarded(let transactionID):
            let grant = try await reportReward(
                network: loaded.network,
                placementID: configuration.unitIDs.rewarded.placementID,
                transactionID: transactionID
            )
            let outcome: AdManagerOutcome = .shown(
                network: loaded.network,
                placement: .rewarded,
                transactionID: transactionID
            )
            lastOutcome = outcome
            return AdRewardOutcome(network: loaded.network, transactionID: transactionID, grant: grant)
        case .dismissed:
            throw AdManagerError.rewardNotEarned
        case .impressed:
            throw AdManagerError.rewardNotEarned
        case .failed(let message):
            throw AdManagerError.showFailed(message)
        }
    }

    private func showAutoPlacement(_ placement: AdPlacement) async -> AdManagerOutcome {
        guard !configuration.isSubscribed() else {
            return finish(.skipped(.subscribed))
        }
        guard frequencyGate.canShow(placement) else {
            return finish(.skipped(.frequencyLimitReached))
        }
        return await present(placement)
    }

    private func present(_ placement: AdPlacement) async -> AdManagerOutcome {
        isShowingAd = true
        defer { isShowingAd = false }

        do {
            let loaded = try await aggregator.loadAndShow(placement: placement)
            switch loaded.result {
            case .impressed(let transactionID), .rewarded(let transactionID):
                frequencyGate.recordShown(placement)
                return finish(.shown(
                    network: loaded.network,
                    placement: placement,
                    transactionID: transactionID
                ))
            case .dismissed:
                return finish(.skipped(.userDismissed))
            case .failed:
                return finish(.skipped(.showFailed))
            }
        } catch AdManagerError.loadFailed {
            return finish(.skipped(.loadFailed))
        } catch AdManagerError.showFailed {
            return finish(.skipped(.showFailed))
        } catch {
            return finish(.skipped(.sdkUnavailable))
        }
    }

    private func finish(_ outcome: AdManagerOutcome) -> AdManagerOutcome {
        lastOutcome = outcome
        return outcome
    }

    private func reportReward(
        network: AdNetwork,
        placementID: String,
        transactionID: String
    ) async throws -> AdRewardGrant {
        guard configuration.tokenStore.refreshToken() != nil else {
            throw AdManagerError.notAuthenticated
        }

        let api = CreditsAPI(client: clientFactory(configuration.tokenStore))
        let request = AdRewardRequest(
            network: network.reportValue,
            placementId: placementID,
            transId: transactionID,
            idfv: configuration.idfvProvider()
        )
        let context = AdRewardRequestContext(
            nonce: configuration.nonceFactory(),
            timestampMs: configuration.timestampFactory()
        )

        do {
            let data = try await api.adReward(request, context: context)
            await creditService?.applyBalance(data.balanceAfter, channel: .rpc)
            return AdRewardGrant(
                grantedCredits: data.grantedCredits,
                balanceAfter: data.balanceAfter,
                ledgerID: data.ledgerId,
                duplicate: data.duplicate ?? false
            )
        } catch {
            throw AdManagerError.reportFailed(error.localizedDescription)
        }
    }
}
