import BabyCameraAIPlay
import BabyCameraNetwork
import BabyCameraNotification
import Foundation

/// 将静默 AI 完成推送接到 `AITaskCoordinator`，供后台下载补偿（INT-08）。
enum NotificationIntegrationBridge {
    private static let lock = NSLock()
    private static weak var taskCoordinator: AITaskCoordinator?

    static func register(taskCoordinator: AITaskCoordinator) {
        lock.lock()
        self.taskCoordinator = taskCoordinator
        lock.unlock()
    }

    static func clear() {
        lock.lock()
        taskCoordinator = nil
        lock.unlock()
    }

    static func applySilentAIDone(_ payload: RemotePushPayload) async {
        guard payload.isSilentAIDone,
              let taskId = payload.taskId,
              let state = payload.state else {
            return
        }

        lock.lock()
        let coordinator = taskCoordinator
        lock.unlock()
        guard let coordinator else { return }

        await coordinator.handlePushNotification(
            AITaskPushPayload(
                taskId: taskId,
                state: state,
                resultUrl: payload.resultUrl,
                thumbnailUrl: payload.thumbnailUrl
            )
        )
    }
}

enum NotificationIntegrationFactory {
    static func configure(
        tokenStore: TokenStore,
        region: AppRegion = .cn,
        urlSession: URLSession = .shared
    ) {
        let regionConfig = RegionConfig(
            region: region,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            deviceId: resolveDeviceId()
        )

        NotificationBootstrap.configure(
            region: region,
            tokenStore: tokenStore,
            regionConfig: regionConfig,
            clientFactory: { tokenStore in
                makeAuthenticatedClient(
                    region: region,
                    tokenStore: tokenStore,
                    regionConfig: regionConfig,
                    session: urlSession
                )
            },
            silentAIDoneHandler: { payload in
                await NotificationIntegrationBridge.applySilentAIDone(payload)
            }
        )
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
