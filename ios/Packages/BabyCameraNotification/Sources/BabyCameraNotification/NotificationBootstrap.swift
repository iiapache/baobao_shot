import BabyCameraNetwork
import Foundation
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif
import UIKit
import UserNotifications

/// App 层推送引导：APNs 授权、Token 注册、静默 AI 完成推送与后台下载（INT-08 / design-ios §10.1）。
public enum NotificationBootstrap {
    public typealias SilentAIDoneHandler = @Sendable (RemotePushPayload) async -> Void

    private static let lock = NSLock()
    private static var registrar: APNsTokenRegistrar?
    private static var silentPushHandler: SilentPushBackgroundHandler?
    private static var silentAIDoneHandler: SilentAIDoneHandler?
    private static var backgroundScheduler: (any BackgroundRefreshScheduling)?
    private static var pendingStore: (any PendingAIRefreshStoring)?
    private static var isBackgroundRefreshRegistered = false

    public static func configure(
        region: AppRegion = .cn,
        tokenStore: TokenStore,
        regionConfig: RegionConfig? = nil,
        clientFactory: (@Sendable (TokenStore) -> APIClient)? = nil,
        tokenProvider: (any APNsTokenProviding)? = nil,
        refreshScheduler: (any BackgroundRefreshScheduling)? = nil,
        pendingStore: (any PendingAIRefreshStoring)? = nil,
        silentAIDoneHandler: SilentAIDoneHandler? = nil
    ) {
        let resolvedRegionConfig = regionConfig ?? RegionConfig(
            region: region,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            deviceId: resolveDeviceId()
        )
        let provider = tokenProvider ?? LiveAPNsTokenStore.shared
        let scheduler = refreshScheduler ?? makeBackgroundScheduler()
        let store = pendingStore ?? UserDefaultsPendingAIRefreshStore()

        lock.lock()
        registrar = APNsTokenRegistrar(
            tokenProvider: provider,
            metadataProvider: LiveDeviceMetadataProvider(regionConfig: resolvedRegionConfig),
            tokenStore: tokenStore,
            clientFactory: clientFactory
        )
        silentPushHandler = SilentPushBackgroundHandler(
            refreshScheduler: scheduler,
            pendingStore: store
        )
        silentAIDoneHandler = silentAIDoneHandler
        backgroundScheduler = scheduler
        self.pendingStore = store
        registerBackgroundRefreshIfNeeded(
            scheduler: scheduler,
            pendingStore: store
        )
        lock.unlock()
    }

    public static func requestAuthorizationAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    public static func handleDeviceToken(_ deviceToken: Data) {
        Task {
            await LiveAPNsTokenStore.shared.updateToken(deviceToken)
            try? await registerCurrentToken(deviceToken)
        }
    }

    @discardableResult
    public static func registerCurrentTokenIfAvailable() async throws -> RegisterDeviceData? {
        guard let token = await LiveAPNsTokenStore.shared.currentToken() else {
            return nil
        }
        return try await registerCurrentToken(token)
    }

    public static func unregisterCurrentDevice() async {
        lock.lock()
        let currentRegistrar = registrar
        lock.unlock()
        try? await currentRegistrar?.unregisterCurrentDevice()
    }

    public static func handleRemoteNotification(
        _ userInfo: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task {
            let result = await processRemoteNotification(userInfo)
            await MainActor.run {
                completionHandler(result)
            }
        }
    }

    public static func processRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        lock.lock()
        let handler = silentPushHandler
        let onSilentAIDone = silentAIDoneHandler
        lock.unlock()

        guard let handler else {
            return .noData
        }

        let outcome = await handler.handle(userInfo: userInfo)
        switch outcome {
        case let .scheduledBackgroundRefresh(payload):
            await onSilentAIDone?(payload)
            return .newData
        case let .failedToSchedule(payload):
            await onSilentAIDone?(payload)
            return .failed
        case .milestoneFallback:
            return .newData
        case .ignored:
            return .noData
        }
    }

    // MARK: - Private

    private static func registerCurrentToken(_ token: Data) async throws -> RegisterDeviceData? {
        lock.lock()
        let currentRegistrar = registrar
        lock.unlock()
        return try await currentRegistrar?.registerToken(token)
    }

    private static func registerBackgroundRefreshIfNeeded(
        scheduler: any BackgroundRefreshScheduling,
        pendingStore: any PendingAIRefreshStoring
    ) {
        guard !isBackgroundRefreshRegistered else { return }
        lock.lock()
        let onSilentAIDone = silentAIDoneHandler
        lock.unlock()

        AIResultBackgroundRefreshRegistrar.register(
            scheduler: scheduler,
            pendingStore: pendingStore,
            executor: ClosureAIResultBackgroundExecutor { payloads in
                for payload in payloads {
                    await onSilentAIDone?(payload)
                }
                return !payloads.isEmpty
            }
        )
        isBackgroundRefreshRegistered = true
    }

    private static func makeBackgroundScheduler() -> any BackgroundRefreshScheduling {
        #if canImport(BackgroundTasks)
        return LiveBackgroundRefreshScheduler()
        #else
        struct NoopScheduler: BackgroundRefreshScheduling {
            func register(identifier: String, handler: @escaping @Sendable () async -> Bool) {}
            func submit(_ request: BackgroundRefreshRequest) async -> Bool { false }
        }
        return NoopScheduler()
        #endif
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
