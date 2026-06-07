import XCTest
@testable import BabyCameraAIPlay

@MainActor
final class AIPlayGridViewModelTests: XCTestCase {
    func testLoadFiltersUnavailablePlays() async {
        let service = MockPlayCatalogService(
            catalog: PlaysCatalog(
                version: "v1",
                region: .cn,
                ttlSeconds: 300,
                plays: [
                    AIPlay(id: "a", name: "A", kind: .image, creditCost: 1, available: true),
                    AIPlay(id: "b", name: "B", kind: .image, creditCost: 1, available: false),
                ]
            )
        )
        let viewModel = AIPlayGridViewModel(catalogService: service)

        await viewModel.load(forceRefresh: true)

        XCTAssertEqual(viewModel.plays.map(\.id), ["a"])
        XCTAssertEqual(viewModel.catalogVersion, "v1")
    }

    func testPinnedPlaysOrderedFirst() async {
        let service = MockPlayCatalogService(
            catalog: PlaysCatalog(
                version: "v1",
                region: .cn,
                ttlSeconds: 300,
                plays: [
                    AIPlay(id: "a", name: "A", kind: .image, creditCost: 1, available: true),
                    AIPlay(id: "b", name: "B", kind: .image, creditCost: 1, available: true),
                    AIPlay(id: "c", name: "C", kind: .image, creditCost: 1, available: true),
                ]
            )
        )
        let viewModel = AIPlayGridViewModel(
            catalogService: service,
            pinnedPlayIDs: ["c", "a"]
        )

        await viewModel.load(forceRefresh: true)

        XCTAssertEqual(viewModel.plays.map(\.id), ["c", "a", "b"])
    }

    func testLoadUsesCachedCatalogOnNetworkFailure() async {
        let cached = PlaysCatalog(
            version: "cached",
            region: .cn,
            ttlSeconds: 300,
            plays: [
                AIPlay(id: "cached", name: "Cached", kind: .image, creditCost: 1, available: true),
            ]
        )
        let service = MockPlayCatalogService(catalog: cached, shouldFail: true, seedCache: true)
        let viewModel = AIPlayGridViewModel(catalogService: service)

        await viewModel.load(forceRefresh: true)

        XCTAssertEqual(viewModel.plays.map(\.id), ["cached"])
        XCTAssertNotNil(viewModel.errorMessage)
    }
}

private struct MockPlayCatalogService: PlayCatalogServing {
    let catalog: PlaysCatalog
    var shouldFail = false
    var seedCache = false

    func fetchCatalog(forceRefresh: Bool) async throws -> PlaysCatalog {
        if shouldFail {
            throw URLError(.notConnectedToInternet)
        }
        return catalog
    }

    func cachedCatalog() async -> PlaysCatalog? {
        seedCache ? catalog : nil
    }
}
