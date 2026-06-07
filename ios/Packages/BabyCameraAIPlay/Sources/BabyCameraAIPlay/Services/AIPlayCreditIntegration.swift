import BabyCameraCredit
import BabyCameraNetwork
import Foundation

/// AI 任务 WebSocket 与积分余额的绑定（T4.16）。
public enum AIPlayCreditBinding {
    @MainActor
    public static func bind(
        creditService: CreditService,
        taskEvents: AsyncStream<AITaskEvent>
    ) {
        let balanceStream = AITaskCreditBalanceBridge.balanceEvents(from: taskEvents)
        creditService.bindWebSocketEvents(balanceStream)
    }
}

public enum AIPlayCreditIntegration {
    @MainActor
    public static func makeDetailViewModel(
        play: AIPlay,
        submissionContext: AIPlaySubmissionContext,
        creditService: CreditService,
        region: AppRegion = .cn,
        tokenStore: TokenStore = KeychainTokenStore(),
        regionConfig: RegionConfig? = nil,
        session: URLSession = .shared,
        selectedDurationSeconds: Int? = nil
    ) -> AIPlayDetailViewModel {
        let previewConfiguration = CreditPreviewServiceConfiguration(
            region: region,
            regionConfig: regionConfig,
            tokenStore: tokenStore,
            session: session
        )
        let previewService = CreditPreviewService(
            configuration: previewConfiguration,
            creditService: creditService
        )
        let submitService = AITaskSubmitService(
            configuration: AITaskSubmitServiceConfiguration(
                region: region,
                regionConfig: regionConfig,
                tokenStore: tokenStore,
                session: session
            )
        )
        return AIPlayDetailViewModel(
            play: play,
            submissionContext: submissionContext,
            previewService: previewService,
            submitService: submitService,
            creditService: creditService,
            selectedDurationSeconds: selectedDurationSeconds
        )
    }

    @MainActor
    public static func makeProgressViewModel(
        created: AITaskCreatedData,
        playName: String,
        coordinator: AITaskCoordinator,
        creditService: CreditService,
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
