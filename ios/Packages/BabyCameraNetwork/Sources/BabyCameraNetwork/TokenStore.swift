import Foundation
import Security

public struct TokenPair: Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let accessTokenExpiresIn: TimeInterval?
    public let refreshTokenExpiresIn: TimeInterval?

    public init(
        accessToken: String,
        refreshToken: String,
        accessTokenExpiresIn: TimeInterval? = nil,
        refreshTokenExpiresIn: TimeInterval? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accessTokenExpiresIn = accessTokenExpiresIn
        self.refreshTokenExpiresIn = refreshTokenExpiresIn
    }
}

public protocol TokenStore: Sendable {
    func accessToken() -> String?
    func refreshToken() -> String?
    func save(_ tokens: TokenPair)
    func clear()
}

/// 内存实现，供单测与 Preview 使用。
public final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var access: String?
    private var refresh: String?

    public init(access: String? = nil, refresh: String? = nil) {
        self.access = access
        self.refresh = refresh
    }

    public func accessToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return access
    }

    public func refreshToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return refresh
    }

    public func save(_ tokens: TokenPair) {
        lock.lock()
        defer { lock.unlock() }
        access = tokens.accessToken
        refresh = tokens.refreshToken
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        access = nil
        refresh = nil
    }
}

/// Keychain 持久化 — `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
public final class KeychainTokenStore: TokenStore, @unchecked Sendable {
    public static let defaultService = "com.babycamera.app.tokens"

    private let lock = NSLock()
    private let service: String
    private let accessAccount: String
    private let refreshAccount: String
    private let accessibility: CFString

    public init(
        service: String = KeychainTokenStore.defaultService,
        accessibility: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ) {
        self.service = service
        self.accessAccount = "\(service).access"
        self.refreshAccount = "\(service).refresh"
        self.accessibility = accessibility
    }

    public func accessToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return read(account: accessAccount)
    }

    public func refreshToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return read(account: refreshAccount)
    }

    public func save(_ tokens: TokenPair) {
        lock.lock()
        defer { lock.unlock() }
        write(account: accessAccount, value: tokens.accessToken)
        write(account: refreshAccount, value: tokens.refreshToken)
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        delete(account: accessAccount)
        delete(account: refreshAccount)
    }

    private func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func write(account: String, value: String) {
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: accessibility,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
