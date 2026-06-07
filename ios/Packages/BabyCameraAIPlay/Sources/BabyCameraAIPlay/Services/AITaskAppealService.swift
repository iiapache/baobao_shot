import BabyCameraCredit
import BabyCameraNetwork
import Foundation

public enum AITaskAppealServiceError: Error, Equatable, Sendable {
    case notAuthenticated
    case emptyReason
}

public protocol AITaskAppealing: Sendable {
    func appeal(taskId: String, reason: String) async throws -> AITaskAppealData
}

public struct LiveAITaskAppealService: AITaskAppealing, Sendable {
    private let api: AITasksAPI

    public init(api: AITasksAPI) {
        self.api = api
    }

    public func appeal(taskId: String, reason: String) async throws -> AITaskAppealData {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AITaskAppealServiceError.emptyReason
        }
        return try await api.appealTask(taskId: taskId, reason: trimmed)
    }
}

public enum AITaskAppealServiceFactory {
    public static func make(
        region: AppRegion = .cn,
        tokenStore: TokenStore = KeychainTokenStore(),
        regionConfig: RegionConfig? = nil,
        session: URLSession = .shared
    ) -> LiveAITaskAppealService {
        let config = regionConfig ?? RegionConfig(region: region, appVersion: "1.0.0", deviceId: "ai-appeal-device")
        let client = makeAuthenticatedClient(
            region: region,
            tokenStore: tokenStore,
            regionConfig: config,
            session: session
        )
        return LiveAITaskAppealService(api: AITasksAPI(client: client))
    }
}

public enum AITaskProgressFactory {
    @MainActor
    public static func makeViewModel(
        created: AITaskCreatedData,
        playName: String,
        coordinator: AITaskCoordinator,
        creditService: CreditService? = nil,
        region: AppRegion = .cn,
        tokenStore: TokenStore = KeychainTokenStore()
    ) -> AITaskProgressViewModel {
        AITaskProgressViewModel(
            created: created,
            playName: playName,
            coordinator: coordinator,
            appealService: AITaskAppealServiceFactory.make(region: region, tokenStore: tokenStore),
            creditService: creditService
        )
    }
}
