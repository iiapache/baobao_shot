import BabyCameraNetwork
import Foundation

@MainActor
public final class AIPlayGridViewModel: ObservableObject {
    @Published public private(set) var plays: [AIPlay] = []
    @Published public private(set) var catalogVersion: String?
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    public let pinnedPlayIDs: [String]
    private let catalogService: any PlayCatalogServing

    public init(
        catalogService: any PlayCatalogServing,
        pinnedPlayIDs: [String] = []
    ) {
        self.catalogService = catalogService
        self.pinnedPlayIDs = pinnedPlayIDs
    }

    public func load(forceRefresh: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let catalog = try await catalogService.fetchCatalog(forceRefresh: forceRefresh)
            catalogVersion = catalog.version
            plays = Self.orderPlays(catalog.availablePlays, pinnedIDs: pinnedPlayIDs)
        } catch {
            errorMessage = mapError(error)
            if let cached = await catalogService.cachedCatalog() {
                catalogVersion = cached.version
                plays = Self.orderPlays(cached.availablePlays, pinnedIDs: pinnedPlayIDs)
            }
        }
    }

    static func orderPlays(_ plays: [AIPlay], pinnedIDs: [String]) -> [AIPlay] {
        guard !pinnedIDs.isEmpty else { return plays }
        var ordered: [AIPlay] = []
        var remaining = plays
        for pinnedID in pinnedIDs {
            guard let index = remaining.firstIndex(where: { $0.id == pinnedID }) else { continue }
            ordered.append(remaining.remove(at: index))
        }
        ordered.append(contentsOf: remaining)
        return ordered
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        if let catalogError = error as? PlayCatalogServiceError {
            switch catalogError {
            case .notAuthenticated:
                return "请先登录"
            }
        }
        return "加载玩法失败，请稍后重试"
    }
}
