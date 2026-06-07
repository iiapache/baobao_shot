import BabyCameraNetwork
import XCTest
@testable import BabyCameraAIPlay

final class PlayCatalogServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testFetchCatalogMapsAvailablePlays() async throws {
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/ai/plays" else { return nil }
            return MockResponse(
                statusCode: 200,
                json: MockServer.aiPlaysCatalogJSON(includeUnavailable: true)
            )
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let service = makeService(tokenStore: tokenStore)

        let catalog = try await service.fetchCatalog(forceRefresh: true)
        XCTAssertEqual(catalog.version, "20250606001")
        XCTAssertEqual(catalog.availablePlays.count, 3)
        XCTAssertFalse(catalog.availablePlays.contains { $0.id == "gpt_portrait" })
    }

    func testCacheReturnsWithinTTLWithoutNetwork() async throws {
        var requestCount = 0
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/ai/plays" else { return nil }
            requestCount += 1
            return MockResponse(statusCode: 200, json: MockServer.aiPlaysCatalogJSON())
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        var currentDate = Date(timeIntervalSince1970: 1_000)
        let service = makeService(tokenStore: tokenStore, now: { currentDate })

        _ = try await service.fetchCatalog(forceRefresh: true)
        currentDate.addTimeInterval(299)
        _ = try await service.fetchCatalog(forceRefresh: false)

        XCTAssertEqual(requestCount, 1)
    }

    func testCacheExpiresAfterFiveMinutes() async throws {
        var requestCount = 0
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/ai/plays" else { return nil }
            requestCount += 1
            return MockResponse(statusCode: 200, json: MockServer.aiPlaysCatalogJSON())
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        var currentDate = Date(timeIntervalSince1970: 1_000)
        let service = makeService(tokenStore: tokenStore, now: { currentDate })

        _ = try await service.fetchCatalog(forceRefresh: true)
        currentDate.addTimeInterval(301)
        _ = try await service.fetchCatalog(forceRefresh: false)

        XCTAssertEqual(requestCount, 2)
    }

    func testForceRefreshBypassesCache() async throws {
        var requestCount = 0
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/ai/plays" else { return nil }
            requestCount += 1
            return MockResponse(statusCode: 200, json: MockServer.aiPlaysCatalogJSON())
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let service = makeService(tokenStore: tokenStore)

        _ = try await service.fetchCatalog(forceRefresh: true)
        _ = try await service.fetchCatalog(forceRefresh: true)

        XCTAssertEqual(requestCount, 2)
    }

    func testRefreshIntervalCapsServerTTL() {
        XCTAssertEqual(
            PlayCatalogService.refreshInterval(ttlSeconds: 600, minimum: 300),
            300
        )
        XCTAssertEqual(
            PlayCatalogService.refreshInterval(ttlSeconds: 300, minimum: 300),
            300
        )
        XCTAssertEqual(
            PlayCatalogService.refreshInterval(ttlSeconds: 0, minimum: 300),
            300
        )
    }

    func testNotAuthenticatedThrows() async {
        let service = makeService(tokenStore: KeychainTokenStore())
        do {
            _ = try await service.fetchCatalog(forceRefresh: true)
            XCTFail("expected notAuthenticated")
        } catch let error as PlayCatalogServiceError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testCacheInvalidatesWhenRegionChanges() async throws {
        var requestCount = 0
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/ai/plays" else { return nil }
            requestCount += 1
            return MockResponse(statusCode: 200, json: MockServer.aiPlaysCatalogJSON())
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))

        let cnService = makeService(tokenStore: tokenStore, region: .cn)
        _ = try await cnService.fetchCatalog(forceRefresh: true)

        let osService = makeService(tokenStore: tokenStore, region: .os)
        _ = try await osService.fetchCatalog(forceRefresh: false)

        XCTAssertEqual(requestCount, 2)
    }

    private func makeService(
        tokenStore: TokenStore,
        region: AppRegion = .cn,
        now: @escaping @Sendable () -> Date = Date.init
    ) -> PlayCatalogService {
        PlayCatalogService(
            configuration: PlayCatalogServiceConfiguration(
                region: region,
                regionConfig: RegionConfig(region: region, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: tokenStore,
                session: MockURLProtocol.makeSession()
            ),
            clientFactory: { tokenStore in
                makeAuthenticatedClient(
                    region: region,
                    tokenStore: tokenStore,
                    regionConfig: RegionConfig(region: region, appVersion: "1.0.0", deviceId: "test-device"),
                    session: MockURLProtocol.makeSession()
                )
            },
            now: now
        )
    }
}
