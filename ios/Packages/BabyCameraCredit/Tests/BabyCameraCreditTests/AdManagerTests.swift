import BabyCameraNetwork
import XCTest
@testable import BabyCameraCredit

@MainActor
final class AdManagerTests: XCTestCase {
    private let day = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 6))!

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeRewardedClient(transactionID: String = "reward-trans-001") -> StubAdSDKClient {
        StubAdSDKClient(
            network: .pangle,
            showResult: .rewarded(transactionID: transactionID),
            transactionIDFactory: { transactionID }
        )
    }

    private func makeManager(
        isSubscribed: @escaping @Sendable () -> Bool = { false },
        frequencyStore: AdFrequencyStoring = InMemoryAdFrequencyStore(),
        clients: [any AdSDKClient]? = nil,
        randomSource: @escaping @Sendable () -> Double = { 0 },
        creditService: CreditService? = nil
    ) -> AdManager {
        let tokenStore = InMemoryTokenStore(access: "access", refresh: "refresh")
        let configuration = AdManagerConfiguration(
            region: .cn,
            regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
            tokenStore: tokenStore,
            session: MockURLProtocol.makeSession(),
            isSubscribed: isSubscribed,
            idfvProvider: { "IDFV-TEST-001" },
            now: { self.day },
            nonceFactory: { "nonce-test-001" },
            timestampFactory: { 1_718_678_400_000 }
        )

        let manager = AdManager(
            configuration: configuration,
            frequencyStore: frequencyStore,
            clients: clients ?? [makeRewardedClient()],
            randomSource: randomSource
        )
        if let creditService {
            manager.bindCreditService(creditService)
        }
        return manager
    }

    func testSubscribedUserSkipsSplash() async {
        let manager = makeManager(isSubscribed: { true })
        let outcome = await manager.showSplashIfNeeded()
        XCTAssertEqual(outcome, .skipped(.subscribed))
    }

    func testSplashFrequencyOnePerDay() async {
        let store = InMemoryAdFrequencyStore()
        let splashClient = StubAdSDKClient(
            network: .pangle,
            showResult: .impressed(transactionID: "splash-1")
        )
        let manager = makeManager(
            frequencyStore: store,
            clients: [splashClient]
        )

        let first = await manager.showSplashIfNeeded()
        XCTAssertEqual(first, .shown(network: .pangle, placement: .splash, transactionID: "splash-1"))

        let second = await manager.showSplashIfNeeded()
        XCTAssertEqual(second, .skipped(.frequencyLimitReached))
    }

    func testInterstitialRespectsFrequencyAndSampling() async {
        let store = InMemoryAdFrequencyStore()
        let interstitialClient = StubAdSDKClient(
            network: .pangle,
            showResult: .impressed(transactionID: "interstitial-1")
        )

        let notSampled = makeManager(
            frequencyStore: store,
            clients: [interstitialClient],
            randomSource: { 0.9 }
        )
        let skipped = await notSampled.showInterstitialIfNeeded()
        XCTAssertEqual(skipped, .skipped(.interstitialNotSampled))

        let sampled = makeManager(
            frequencyStore: store,
            clients: [interstitialClient],
            randomSource: { 0.1 }
        )
        let shown = await sampled.showInterstitialIfNeeded()
        XCTAssertEqual(shown, .shown(network: .pangle, placement: .interstitial, transactionID: "interstitial-1"))
    }

    func testSubscribedUserSkipsInterstitial() async {
        let manager = makeManager(isSubscribed: { true })
        let outcome = await manager.showInterstitialIfNeeded()
        XCTAssertEqual(outcome, .skipped(.subscribed))
    }

    func testRewardedAdReportsCreditsAndUpdatesBalance() async throws {
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/credits/ad-reward" else { return nil }
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Nonce"), "nonce-test-001")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Timestamp"), "1718678400000")
            return MockResponse(statusCode: 200, json: MockServer.adRewardSuccessJSON(
                grantedCredits: 5,
                balanceAfter: 128
            ))
        }

        let creditService = CreditService(
            configuration: CreditServiceConfiguration(
                region: .cn,
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: InMemoryTokenStore(access: "access", refresh: "refresh"),
                session: MockURLProtocol.makeSession()
            )
        )

        let manager = makeManager(
            clients: [makeRewardedClient(transactionID: "client-trans-001")],
            creditService: creditService
        )

        let outcome = try await manager.showRewardedAd()
        XCTAssertEqual(outcome.network, .pangle)
        XCTAssertEqual(outcome.transactionID, "client-trans-001")
        XCTAssertEqual(outcome.grant.grantedCredits, 5)
        XCTAssertEqual(outcome.grant.balanceAfter, 128)
        XCTAssertEqual(creditService.balance, 128)
    }

    func testSubscribedUserCanStillWatchRewardedAd() async throws {
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/credits/ad-reward" else { return nil }
            return MockResponse(statusCode: 200, json: MockServer.adRewardSuccessJSON())
        }

        let manager = makeManager(
            isSubscribed: { true },
            clients: [makeRewardedClient(transactionID: "sub-reward-trans")]
        )

        let outcome = try await manager.showRewardedAd()
        XCTAssertEqual(outcome.transactionID, "sub-reward-trans")
    }

    func testRewardedAdRequiresFullWatch() async {
        let dismissClient = StubAdSDKClient(
            network: .pangle,
            showResult: .dismissed
        )
        let manager = makeManager(clients: [dismissClient])

        do {
            _ = try await manager.showRewardedAd()
            XCTFail("expected rewardNotEarned")
        } catch let error as AdManagerError {
            XCTAssertEqual(error, .rewardNotEarned)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
