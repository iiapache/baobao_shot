import BabyCameraCredit
import BabyCameraNetwork
import Foundation

public enum CreditPreviewServiceError: Error, Equatable, Sendable {
    case notAuthenticated
}

public protocol CreditPreviewServing: Sendable {
    func preview(play: AIPlay, durationSeconds: Int?) async throws -> CreditPreview
}

public struct CreditPreviewServiceConfiguration: Sendable {
    public let region: AppRegion
    public let regionConfig: RegionConfig
    public let tokenStore: TokenStore
    public let session: URLSession

    public init(
        region: AppRegion = .cn,
        regionConfig: RegionConfig? = nil,
        tokenStore: TokenStore = KeychainTokenStore(),
        session: URLSession = .shared
    ) {
        self.region = region
        self.regionConfig = regionConfig ?? RegionConfig(
            region: region,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            deviceId: "preview-device"
        )
        self.tokenStore = tokenStore
        self.session = session
    }
}

public final class CreditPreviewService: @unchecked Sendable, CreditPreviewServing {
    private let tokenStore: TokenStore
    private let clientFactory: @Sendable (TokenStore) -> APIClient
    private weak var creditService: (any CreditServing)?

    public init(
        configuration: CreditPreviewServiceConfiguration = CreditPreviewServiceConfiguration(),
        creditService: (any CreditServing)? = nil,
        clientFactory: (@Sendable (TokenStore) -> APIClient)? = nil
    ) {
        self.tokenStore = configuration.tokenStore
        self.creditService = creditService
        self.clientFactory = clientFactory ?? { tokenStore in
            makeAuthenticatedClient(
                region: configuration.region,
                tokenStore: tokenStore,
                regionConfig: configuration.regionConfig,
                session: configuration.session
            )
        }
    }

    public func preview(play: AIPlay, durationSeconds: Int?) async throws -> CreditPreview {
        guard tokenStore.refreshToken() != nil else {
            throw CreditPreviewServiceError.notAuthenticated
        }

        let localCost = CreditCostCalculator.cost(for: play, durationSeconds: durationSeconds)

        if let creditService {
            let costPreview = try await creditService.previewCost(
                playId: play.id,
                durationSeconds: durationSeconds,
                localCost: localCost
            )
            return CreditPreview(
                costCredits: costPreview.costCredits,
                balance: costPreview.balance,
                signInAvailable: costPreview.signInAvailable
            )
        }

        let api = CreditsAPI(client: clientFactory(tokenStore))
        let costCredits = try await resolveRemoteCost(
            api: api,
            playId: play.id,
            durationSeconds: durationSeconds,
            fallback: localCost
        )
        let balanceData = try await api.balance()
        return CreditPreview(
            costCredits: costCredits,
            balance: balanceData.balance,
            signInAvailable: balanceData.signInAvailable
        )
    }

    private func resolveRemoteCost(
        api: CreditsAPI,
        playId: String,
        durationSeconds: Int?,
        fallback: Int
    ) async throws -> Int {
        do {
            let rates = try await api.rates()
            if let remoteCost = rates.cost(for: playId, durationSeconds: durationSeconds) {
                return remoteCost
            }
        } catch {
            return fallback
        }
        return fallback
    }
}
