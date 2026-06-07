import Foundation

/// 百度网盘备份 Provider：OAuth stub + OpenAPI 分片上传 + Token 入 Keychain（T6.5）。
public struct BaiduPanProvider: BackupProvider, Sendable {
    public static let defaultRemoteDirectory = "/apps/babycamera/backups"
    public static let listPageSize = 100

    public let kind: BackupKind = .baiduPan

    private let oauth: any BaiduPanOAuthProviding
    private let openAPI: any BaiduPanOpenAPIProviding
    private let tokenStore: any BaiduPanTokenStoring
    private let ledger: any BaiduPanUploadLedger
    private let remoteDirectory: String
    private let clock: any BackupClock

    public init(
        oauth: any BaiduPanOAuthProviding,
        openAPI: any BaiduPanOpenAPIProviding,
        tokenStore: any BaiduPanTokenStoring,
        ledger: any BaiduPanUploadLedger = InMemoryBaiduPanUploadLedger(),
        remoteDirectory: String = BaiduPanProvider.defaultRemoteDirectory,
        clock: any BackupClock = SystemBackupClock()
    ) {
        self.oauth = oauth
        self.openAPI = openAPI
        self.tokenStore = tokenStore
        self.ledger = ledger
        self.remoteDirectory = remoteDirectory
        self.clock = clock
    }

    public static func stub(
        oauth: any BaiduPanOAuthProviding = StubBaiduPanOAuthService(),
        openAPI: any BaiduPanOpenAPIProviding = MockBaiduPanOpenAPIClient(),
        tokenStore: any BaiduPanTokenStoring = InMemoryBaiduPanTokenStore(),
        ledger: any BaiduPanUploadLedger = InMemoryBaiduPanUploadLedger()
    ) -> BaiduPanProvider {
        BaiduPanProvider(
            oauth: oauth,
            openAPI: openAPI,
            tokenStore: tokenStore,
            ledger: ledger
        )
    }

    public static func live(
        tokenStore: any BaiduPanTokenStoring = KeychainBaiduPanTokenStore(),
        ledger: any BaiduPanUploadLedger = InMemoryBaiduPanUploadLedger()
    ) -> BaiduPanProvider {
        BaiduPanProvider(
            oauth: LiveBaiduPanOAuthService(),
            openAPI: BaiduPanOpenAPIClient(),
            tokenStore: tokenStore,
            ledger: ledger
        )
    }

    public func authorize() async throws {
        if let existing = tokenStore.load(),
           !existing.accessToken.isEmpty,
           !isExpired(existing.expiresAt) {
            return
        }

        let credentials = try await oauth.authorize()
        tokenStore.save(credentials)
    }

    public func quota() async throws -> BackupQuota {
        let accessToken = try requireAccessToken()
        let info = try await openAPI.fetchQuota(accessToken: accessToken)
        return BackupQuota(usedBytes: info.usedBytes, totalBytes: info.totalBytes)
    }

    public func upload(_ item: BackupItem) async throws -> BackupReceipt {
        try await authorize()

        let fileURL = URL(fileURLWithPath: item.filePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw BaiduPanProviderError.localFileNotFound(path: item.filePath)
        }

        let accessToken = try requireAccessToken()
        let remotePath = Self.remotePath(
            directory: remoteDirectory,
            photoId: item.photoId,
            sha256: item.sha256,
            mimeType: item.mimeType
        )

        let result = try await openAPI.uploadFile(
            accessToken: accessToken,
            localFileURL: fileURL,
            remotePath: remotePath,
            resumeState: nil,
            chunkSize: BaiduPanOpenAPIConfiguration().defaultChunkSize,
            onProgress: nil
        )

        let remoteFile = BaiduPanRemoteFile(
            fsId: result.fsId,
            remotePath: result.remotePath,
            sha256: item.sha256,
            byteSize: item.byteSize
        )
        await ledger.record(remoteFile)

        return BackupReceipt(
            remoteId: String(result.fsId),
            sha256: item.sha256,
            uploadedAt: clock.nowUnixMillis()
        )
    }

    public func list(after cursor: String?) async throws -> BackupPage {
        try await authorize()
        return await ledger.page(after: cursor, limit: Self.listPageSize)
    }

    public func revoke() async throws {
        tokenStore.clear()
        await ledger.clear()
    }

    private func requireAccessToken() throws -> String {
        guard let token = tokenStore.load()?.accessToken, !token.isEmpty else {
            throw BaiduPanProviderError.notAuthorized
        }
        return token
    }

    private func isExpired(_ expiresAt: Date?) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date()
    }

    static func remotePath(
        directory: String,
        photoId: String,
        sha256: String,
        mimeType: String
    ) -> String {
        let ext: String
        switch mimeType.lowercased() {
        case "image/jpeg", "image/jpg":
            ext = "jpg"
        case "image/png":
            ext = "png"
        case "video/mp4":
            ext = "mp4"
        default:
            ext = "heic"
        }
        let normalizedDirectory = directory.hasSuffix("/") ? String(directory.dropLast()) : directory
        return "\(normalizedDirectory)/\(photoId)_\(sha256).\(ext)"
    }
}
