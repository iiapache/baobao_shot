import Foundation

/// 保存系统回调的最新 APNs Token，供登录后补注册。
public actor LiveAPNsTokenStore: APNsTokenProviding {
    public static let shared = LiveAPNsTokenStore()

    private var latestToken: Data?

    public init() {}

    public func updateToken(_ token: Data) {
        latestToken = token
    }

    public func currentToken() async -> Data? {
        latestToken
    }
}
