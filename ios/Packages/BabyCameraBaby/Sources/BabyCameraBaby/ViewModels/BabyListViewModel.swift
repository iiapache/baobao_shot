import BabyCameraNetwork
import Foundation

@MainActor
public final class BabyListViewModel: ObservableObject {
    @Published public private(set) var babies: [BabyProfile] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    private let service: BabyService
    private let currentBabyStore: CurrentBabyEnvironment

    public init(service: BabyService, currentBabyStore: CurrentBabyEnvironment) {
        self.service = service
        self.currentBabyStore = currentBabyStore
    }

    public var currentBabyId: String? {
        currentBabyStore.currentBabyId
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let items = try await service.listBabies()
            babies = items
            currentBabyStore.replaceBabies(items)
        } catch {
            errorMessage = mapError(error)
        }
    }

    public func selectBaby(id: String) {
        currentBabyStore.select(babyId: id)
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        return "加载失败，请稍后重试"
    }
}
