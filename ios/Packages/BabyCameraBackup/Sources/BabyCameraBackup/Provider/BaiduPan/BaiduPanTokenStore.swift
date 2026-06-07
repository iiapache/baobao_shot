import Foundation
import Security

public protocol BaiduPanTokenStoring: Sendable {
    func load() -> BaiduPanCredentials?
    func save(_ credentials: BaiduPanCredentials)
    func clear()
}

/// 内存实现，供单测与 Preview 使用。
public final class InMemoryBaiduPanTokenStore: BaiduPanTokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var credentials: BaiduPanCredentials?

    public init(credentials: BaiduPanCredentials? = nil) {
        self.credentials = credentials
    }

    public func load() -> BaiduPanCredentials? {
        lock.lock()
        defer { lock.unlock() }
        return credentials
    }

    public func save(_ credentials: BaiduPanCredentials) {
        lock.lock()
        defer { lock.unlock() }
        self.credentials = credentials
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        credentials = nil
    }
}

/// 百度 OAuth Token Keychain 持久化 — `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
public final class KeychainBaiduPanTokenStore: BaiduPanTokenStoring, @unchecked Sendable {
    public static let defaultService = "com.babycamera.app.baidu-pan"
    public static let defaultAccessibility: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    private let lock = NSLock()
    private let service: String
    private let account: String
    private let accessibility: CFString
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        service: String = KeychainBaiduPanTokenStore.defaultService,
        account: String = "credentials",
        accessibility: CFString = KeychainBaiduPanTokenStore.defaultAccessibility
    ) {
        self.service = service
        self.account = account
        self.accessibility = accessibility
    }

    public func load() -> BaiduPanCredentials? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = readData() else { return nil }
        return try? decoder.decode(BaiduPanCredentialsPayload.self, from: data).credentials
    }

    public func save(_ credentials: BaiduPanCredentials) {
        lock.lock()
        defer { lock.unlock() }
        let payload = BaiduPanCredentialsPayload(credentials: credentials)
        guard let data = try? encoder.encode(payload) else { return }
        writeData(data)
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        deleteData()
    }

    private func readData() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return data
    }

    private func writeData(_ data: Data) {
        deleteData()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteData() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private struct BaiduPanCredentialsPayload: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let providerAccountId: String?

    init(credentials: BaiduPanCredentials) {
        accessToken = credentials.accessToken
        refreshToken = credentials.refreshToken
        expiresAt = credentials.expiresAt
        providerAccountId = credentials.providerAccountId
    }

    var credentials: BaiduPanCredentials {
        BaiduPanCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            providerAccountId: providerAccountId
        )
    }
}
