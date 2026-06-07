import BabyCameraNetwork
import Foundation

public enum PlayCatalogServiceError: Error, Equatable, Sendable {
    case notAuthenticated
}

public protocol PlayCatalogServing: Sendable {
    func fetchCatalog(forceRefresh: Bool) async throws -> PlaysCatalog
    func cachedCatalog() async -> PlaysCatalog?
}

public struct PlayCatalogServiceConfiguration: Sendable {
    public static let defaultRefreshInterval: TimeInterval = 300

    public let region: AppRegion
    public let regionConfig: RegionConfig
    public let tokenStore: TokenStore
    public let session: URLSession
    public let minimumRefreshInterval: TimeInterval

    public init(
        region: AppRegion = .cn,
        regionConfig: RegionConfig? = nil,
        tokenStore: TokenStore = KeychainTokenStore(),
        session: URLSession = .shared,
        minimumRefreshInterval: TimeInterval = Self.defaultRefreshInterval
    ) {
        self.region = region
        self.regionConfig = regionConfig ?? RegionConfig(
            region: region,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            deviceId: Self.resolveDeviceId()
        )
        self.tokenStore = tokenStore
        self.session = session
        self.minimumRefreshInterval = minimumRefreshInterval
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

actor PlayCatalogCache {
    private var entry: CachedPlaysCatalog?

    struct CachedPlaysCatalog: Sendable {
        let catalog: PlaysCatalog
        let fetchedAt: Date
        let refreshInterval: TimeInterval
    }

    func catalog(for region: AppRegion, at date: Date) -> PlaysCatalog? {
        guard let entry, entry.catalog.region == region else {
            return nil
        }
        guard date.timeIntervalSince(entry.fetchedAt) < entry.refreshInterval else {
            return nil
        }
        return entry.catalog
    }

    func store(_ catalog: PlaysCatalog, fetchedAt: Date, refreshInterval: TimeInterval) {
        entry = CachedPlaysCatalog(
            catalog: catalog,
            fetchedAt: fetchedAt,
            refreshInterval: refreshInterval
        )
    }

    func invalidate() {
        entry = nil
    }
}

public final class PlayCatalogService: @unchecked Sendable, PlayCatalogServing {
    public let region: AppRegion
    public let tokenStore: TokenStore

    private let regionConfig: RegionConfig
    private let session: URLSession
    private let minimumRefreshInterval: TimeInterval
    private let cache = PlayCatalogCache()
    private let clientFactory: @Sendable (TokenStore) -> APIClient
    private let now: @Sendable () -> Date

    public init(
        configuration: PlayCatalogServiceConfiguration = PlayCatalogServiceConfiguration(),
        clientFactory: (@Sendable (TokenStore) -> APIClient)? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.region = configuration.region
        self.regionConfig = configuration.regionConfig
        self.tokenStore = configuration.tokenStore
        self.session = configuration.session
        self.minimumRefreshInterval = configuration.minimumRefreshInterval
        self.now = now
        self.clientFactory = clientFactory ?? { tokenStore in
            makeAuthenticatedClient(
                region: configuration.region,
                tokenStore: tokenStore,
                regionConfig: configuration.regionConfig,
                session: configuration.session
            )
        }
    }

    public func cachedCatalog() async -> PlaysCatalog? {
        await cache.catalog(for: region, at: now())
    }

    public func fetchCatalog(forceRefresh: Bool = false) async throws -> PlaysCatalog {
        if !forceRefresh, let cached = await cache.catalog(for: region, at: now()) {
            return cached
        }

        guard tokenStore.refreshToken() != nil else {
            throw PlayCatalogServiceError.notAuthenticated
        }

        let api = AIPlaysAPI(client: clientFactory(tokenStore))
        let data = try await api.listPlays()
        let catalog = Self.mapCatalog(data, region: region)
        let refreshInterval = Self.refreshInterval(
            ttlSeconds: data.ttlSeconds,
            minimum: minimumRefreshInterval
        )
        await cache.store(catalog, fetchedAt: now(), refreshInterval: refreshInterval)
        return catalog
    }

    public func invalidateCache() async {
        await cache.invalidate()
    }

    static func refreshInterval(ttlSeconds: Int, minimum: TimeInterval) -> TimeInterval {
        guard ttlSeconds > 0 else { return minimum }
        return min(TimeInterval(ttlSeconds), minimum)
    }

    static func mapCatalog(_ data: AIPlaysCatalogData, region: AppRegion) -> PlaysCatalog {
        let plays = data.plays.map { item in
            AIPlay(
                id: item.id,
                name: item.name,
                description: item.description,
                kind: AIPlayKind(rawKind: item.kind),
                creditCost: item.creditCost,
                durationTiers: (item.durationTiers ?? []).map {
                    AIPlayDurationTier(
                        durationSeconds: $0.durationSeconds,
                        creditCost: $0.creditCost
                    )
                },
                available: item.available
            )
        }
        return PlaysCatalog(
            version: data.version,
            region: region,
            ttlSeconds: TimeInterval(data.ttlSeconds),
            plays: plays
        )
    }
}
