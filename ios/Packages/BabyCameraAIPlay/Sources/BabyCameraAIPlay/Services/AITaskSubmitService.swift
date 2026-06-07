import BabyCameraNetwork
import Foundation

public enum AITaskSubmitServiceError: Error, Equatable, Sendable {
    case notAuthenticated
}

public protocol AITaskSubmitting: Sendable {
    func submit(
        play: AIPlay,
        context: AIPlaySubmissionContext,
        durationSeconds: Int?
    ) async throws -> AITaskCreatedData
}

public struct AITaskSubmitServiceConfiguration: Sendable {
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
            deviceId: "submit-device"
        )
        self.tokenStore = tokenStore
        self.session = session
    }
}

public final class AITaskSubmitService: @unchecked Sendable, AITaskSubmitting {
    private let tokenStore: TokenStore
    private let clientFactory: @Sendable (TokenStore) -> APIClient

    public init(
        configuration: AITaskSubmitServiceConfiguration = AITaskSubmitServiceConfiguration(),
        clientFactory: (@Sendable (TokenStore) -> APIClient)? = nil
    ) {
        self.tokenStore = configuration.tokenStore
        self.clientFactory = clientFactory ?? { tokenStore in
            makeAuthenticatedClient(
                region: configuration.region,
                tokenStore: tokenStore,
                regionConfig: configuration.regionConfig,
                session: configuration.session
            )
        }
    }

    public func submit(
        play: AIPlay,
        context: AIPlaySubmissionContext,
        durationSeconds: Int?
    ) async throws -> AITaskCreatedData {
        guard tokenStore.refreshToken() != nil else {
            throw AITaskSubmitServiceError.notAuthenticated
        }

        let params: AITaskSubmitParams?
        if play.kind == .video, let durationSeconds {
            params = AITaskSubmitParams(
                duration: durationSeconds,
                aspectRatio: context.aspectRatio
            )
        } else {
            params = AITaskSubmitParams(aspectRatio: context.aspectRatio)
        }

        let request = AITaskSubmitRequest(
            play: play.id,
            inputObjectKey: context.inputObjectKey,
            familyId: context.familyId,
            params: params
        )
        let api = AITasksAPI(client: clientFactory(tokenStore))
        return try await api.createTask(request)
    }
}
