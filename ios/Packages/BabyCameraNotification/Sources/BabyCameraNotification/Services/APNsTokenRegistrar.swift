import BabyCameraNetwork
import Foundation

public enum APNsTokenRegistrarError: Error, Equatable, Sendable {
    case missingToken
    case notAuthenticated
}

/// 将 APNs Token 注册/注销到 notification-svc（design-ios §10.1）。
public final class APNsTokenRegistrar: @unchecked Sendable {
    private let tokenProvider: any APNsTokenProviding
    private let metadataProvider: any DeviceMetadataProviding
    private let tokenStore: TokenStore
    private let clientFactory: @Sendable (TokenStore) -> APIClient

    public init(
        tokenProvider: any APNsTokenProviding,
        metadataProvider: any DeviceMetadataProviding,
        tokenStore: TokenStore = KeychainTokenStore(),
        clientFactory: (@Sendable (TokenStore) -> APIClient)? = nil
    ) {
        self.tokenProvider = tokenProvider
        self.metadataProvider = metadataProvider
        self.tokenStore = tokenStore
        self.clientFactory = clientFactory ?? { tokenStore in
            makeAuthenticatedClient(tokenStore: tokenStore)
        }
    }

    /// 注册当前设备 Token；无 Token 时静默跳过。
    @discardableResult
    public func registerCurrentTokenIfAvailable() async throws -> RegisterDeviceData? {
        guard let tokenData = await tokenProvider.currentToken() else {
            return nil
        }
        return try await registerToken(tokenData)
    }

    /// 注册指定 APNs Token（AppDelegate 回调时调用）。
    @discardableResult
    public func registerToken(_ tokenData: Data) async throws -> RegisterDeviceData {
        guard tokenStore.refreshToken() != nil else {
            throw APNsTokenRegistrarError.notAuthenticated
        }

        let request = RegisterDeviceRequest(
            deviceId: metadataProvider.deviceId,
            apnsToken: APNsTokenFormatter.hexString(from: tokenData),
            appVersion: metadataProvider.appVersion,
            osVersion: metadataProvider.osVersion,
            model: metadataProvider.model
        )
        return try await NotificationsAPI(client: clientFactory(tokenStore)).registerDevice(request)
    }

    /// 注销当前设备（登出 / 卸载提示时调用）。
    public func unregisterCurrentDevice() async throws {
        guard tokenStore.refreshToken() != nil else {
            throw APNsTokenRegistrarError.notAuthenticated
        }
        try await NotificationsAPI(client: clientFactory(tokenStore))
            .unregisterDevice(deviceId: metadataProvider.deviceId)
    }
}
