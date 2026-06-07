import BabyCameraNetwork
import Foundation

public struct CreditServiceConfiguration: Sendable {
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
            deviceId: CreditServiceConfiguration.resolveDeviceId()
        )
        self.tokenStore = tokenStore
        self.session = session
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

/// 积分单一事实源：RPC 拉取余额 + WebSocket `balanceAfter` 推送。
@MainActor
public final class CreditService: ObservableObject, CreditServing {
    @Published public private(set) var balance: Int = 0
    @Published public private(set) var signInAvailable: Bool = false
    @Published public private(set) var currentSignInStreak: Int = 0
    @Published public private(set) var isRefreshingBalance = false

    public let tokenStore: TokenStore
    public let region: AppRegion

    private static let streakDefaultsKey = "com.babycamera.credit.lastSignInStreak"

    private let regionConfig: RegionConfig
    private let session: URLSession
    private let clientFactory: @Sendable (TokenStore) -> APIClient
    private var webSocketTask: Task<Void, Never>?

    public init(
        configuration: CreditServiceConfiguration = CreditServiceConfiguration(),
        clientFactory: (@Sendable (TokenStore) -> APIClient)? = nil
    ) {
        self.region = configuration.region
        self.regionConfig = configuration.regionConfig
        self.tokenStore = configuration.tokenStore
        self.session = configuration.session
        self.clientFactory = clientFactory ?? { tokenStore in
            makeAuthenticatedClient(
                region: configuration.region,
                tokenStore: tokenStore,
                regionConfig: configuration.regionConfig,
                session: configuration.session
            )
        }
        self.currentSignInStreak = UserDefaults.standard.integer(forKey: Self.streakDefaultsKey)
    }

    public func refreshBalance() async throws {
        guard !isRefreshingBalance else { return }
        isRefreshingBalance = true
        defer { isRefreshingBalance = false }

        let data = try await api().balance()
        applyBalance(data.balance, channel: .rpc)
        signInAvailable = data.signInAvailable
    }

    public func signIn() async throws -> SignInResult {
        let data = try await api().signIn()
        let result = SignInResult(data: data)
        applyBalance(result.balanceAfter, channel: .rpc)
        signInAvailable = false
        persistSignInStreak(result.streak)
        return result
    }

    public func fetchTransactions(
        cursor: String? = nil,
        limit: Int = CreditsAPI.defaultTransactionPageSize
    ) async throws -> CreditTransactionsPage {
        let data = try await api().transactions(cursor: cursor, limit: limit)
        let items = data.items.map(CreditTransaction.init(item:))
        return CreditTransactionsPage(items: items, nextCursor: data.nextCursor)
    }

    public func bindWebSocketEvents(_ events: AsyncStream<AITaskBalanceEvent>) {
        webSocketTask?.cancel()
        webSocketTask = Task { [weak self] in
            for await event in events {
                guard !Task.isCancelled else { break }
                await self?.applyBalance(event.balanceAfter, channel: .webSocket)
            }
        }
    }

    public func unbindWebSocketEvents() {
        webSocketTask?.cancel()
        webSocketTask = nil
    }

    public func applyBalance(_ newBalance: Int, channel: BalanceUpdateChannel) {
        balance = newBalance
        _ = channel
    }

    public func applyBalanceFromAITask(_ balanceAfter: Int) {
        applyBalance(balanceAfter, channel: .webSocket)
    }

    public func previewCost(
        playId: String,
        durationSeconds: Int?,
        localCost: Int
    ) async throws -> CreditCostPreview {
        let balanceData = try await api().balance()
        applyBalance(balanceData.balance, channel: .rpc)
        signInAvailable = balanceData.signInAvailable

        let costCredits = try await resolveRemoteCost(
            playId: playId,
            durationSeconds: durationSeconds,
            fallback: localCost
        )

        return CreditCostPreview(
            costCredits: costCredits,
            balance: balance,
            signInAvailable: signInAvailable
        )
    }

    private func resolveRemoteCost(
        playId: String,
        durationSeconds: Int?,
        fallback: Int
    ) async throws -> Int {
        do {
            let rates = try await api().rates()
            if let remoteCost = rates.cost(for: playId, durationSeconds: durationSeconds) {
                return remoteCost
            }
        } catch {
            return fallback
        }
        return fallback
    }

    private func api() throws -> CreditsAPI {
        guard tokenStore.refreshToken() != nil else {
            throw CreditServiceError.notAuthenticated
        }
        return CreditsAPI(client: clientFactory(tokenStore))
    }

    private func persistSignInStreak(_ streak: Int) {
        currentSignInStreak = streak
        UserDefaults.standard.set(streak, forKey: Self.streakDefaultsKey)
    }
}

public enum BalanceUpdateChannel: Sendable, Equatable {
    case rpc
    case webSocket
}
