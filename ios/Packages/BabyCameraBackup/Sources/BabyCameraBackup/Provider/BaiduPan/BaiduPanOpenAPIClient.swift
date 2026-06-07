import Foundation

public protocol BaiduPanOpenAPIProviding: Sendable {
    func fetchQuota(accessToken: String) async throws -> BaiduPanQuotaInfo
    func listFiles(accessToken: String, directory: String, start: Int, limit: Int) async throws -> BaiduPanFileListPage
    func uploadFile(
        accessToken: String,
        localFileURL: URL,
        remotePath: String,
        resumeState: BaiduPanMultipartState?,
        chunkSize: Int,
        onProgress: (@Sendable (Int64) -> Void)?
    ) async throws -> BaiduPanUploadResult
}

public struct BaiduPanOpenAPIConfiguration: Sendable, Equatable {
    public let panBaseURL: URL
    public let pcsBaseURL: URL
    public let defaultChunkSize: Int

    public init(
        panBaseURL: URL = URL(string: "https://pan.baidu.com")!,
        pcsBaseURL: URL = URL(string: "https://d.pcs.baidu.com")!,
        defaultChunkSize: Int = 4 * 1024 * 1024
    ) {
        self.panBaseURL = panBaseURL
        self.pcsBaseURL = pcsBaseURL
        self.defaultChunkSize = defaultChunkSize
    }
}

public protocol BaiduPanHTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionBaiduPanTransport: BaiduPanHTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BaiduPanProviderError.uploadFailed("invalid response")
        }
        return (data, http)
    }
}

/// 百度 OpenAPI 客户端 stub：precreate → superfile2 分片 → create。
public final class BaiduPanOpenAPIClient: BaiduPanOpenAPIProviding, @unchecked Sendable {
    private let transport: BaiduPanHTTPTransport
    private let configuration: BaiduPanOpenAPIConfiguration
    private let uploader: BaiduPanChunkUploader

    public init(
        transport: BaiduPanHTTPTransport = URLSessionBaiduPanTransport(),
        configuration: BaiduPanOpenAPIConfiguration = BaiduPanOpenAPIConfiguration()
    ) {
        self.transport = transport
        self.configuration = configuration
        self.uploader = BaiduPanChunkUploader(transport: transport, configuration: configuration)
    }

    public func fetchQuota(accessToken: String) async throws -> BaiduPanQuotaInfo {
        var components = URLComponents(
            url: configuration.panBaseURL.appendingPathComponent("/api/quota"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "access_token", value: accessToken)]

        guard let url = components?.url else {
            throw BaiduPanProviderError.quotaUnavailable
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await transport.data(for: request)
        guard (200 ... 299).contains(response.statusCode) else {
            throw BaiduPanProviderError.openAPI(code: response.statusCode, message: "quota request failed")
        }

        let payload = try JSONDecoder().decode(BaiduPanQuotaResponse.self, from: data)
        guard payload.errno == 0 else {
            throw BaiduPanProviderError.openAPI(code: payload.errno, message: payload.errmsg ?? "quota error")
        }
        return BaiduPanQuotaInfo(usedBytes: payload.used, totalBytes: payload.total)
    }

    public func listFiles(
        accessToken: String,
        directory: String,
        start: Int,
        limit: Int
    ) async throws -> BaiduPanFileListPage {
        var components = URLComponents(
            url: configuration.panBaseURL.appendingPathComponent("/rest/2.0/xpan/file"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "method", value: "list"),
            URLQueryItem(name: "access_token", value: accessToken),
            URLQueryItem(name: "dir", value: directory),
            URLQueryItem(name: "start", value: String(start)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = components?.url else {
            throw BaiduPanProviderError.openAPI(code: -1, message: "invalid list url")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await transport.data(for: request)
        guard (200 ... 299).contains(response.statusCode) else {
            throw BaiduPanProviderError.openAPI(code: response.statusCode, message: "list request failed")
        }

        let payload = try JSONDecoder().decode(BaiduPanListResponse.self, from: data)
        guard payload.errno == 0 else {
            throw BaiduPanProviderError.openAPI(code: payload.errno, message: payload.errmsg ?? "list error")
        }

        let files = (payload.list ?? []).compactMap { entry -> BaiduPanRemoteFile? in
            guard let fsId = entry.fs_id,
                  let path = entry.path,
                  let sha256 = entry.sha256(from: entry.server_filename) else {
                return nil
            }
            return BaiduPanRemoteFile(
                fsId: fsId,
                remotePath: path,
                sha256: sha256,
                byteSize: entry.size ?? 0
            )
        }

        let nextStart = payload.hasMore == true ? start + files.count : nil
        return BaiduPanFileListPage(files: files, nextStart: nextStart)
    }

    public func uploadFile(
        accessToken: String,
        localFileURL: URL,
        remotePath: String,
        resumeState: BaiduPanMultipartState?,
        chunkSize: Int = 4 * 1024 * 1024,
        onProgress: (@Sendable (Int64) -> Void)? = nil
    ) async throws -> BaiduPanUploadResult {
        try await uploader.upload(
            accessToken: accessToken,
            localFileURL: localFileURL,
            remotePath: remotePath,
            resumeState: resumeState,
            chunkSize: chunkSize,
            onProgress: onProgress
        )
    }
}

private struct BaiduPanQuotaResponse: Decodable {
    let errno: Int
    let errmsg: String?
    let total: Int64
    let used: Int64
}

private struct BaiduPanListResponse: Decodable {
    struct Entry: Decodable {
        let fs_id: Int64?
        let path: String?
        let server_filename: String?
        let size: Int64?
    }

    let errno: Int
    let errmsg: String?
    let list: [Entry]?
    let hasMore: Bool?

    enum CodingKeys: String, CodingKey {
        case errno, errmsg, list
        case hasMore = "has_more"
    }
}

private extension BaiduPanListResponse.Entry {
    /// 文件名约定 `{photoId}_{sha256}.heic`，从文件名解析 sha256。
    func sha256(from filename: String?) -> String? {
        guard let filename else { return nil }
        let base = (filename as NSString).deletingPathExtension
        let parts = base.split(separator: "_")
        guard parts.count >= 2 else { return nil }
        return String(parts.last!)
    }
}

/// 供单测注入的 Mock 客户端。
public final class MockBaiduPanOpenAPIClient: BaiduPanOpenAPIProviding, @unchecked Sendable {
    public var quotaResult: BaiduPanQuotaInfo = BaiduPanQuotaInfo(usedBytes: 0, totalBytes: 10_737_418_240)
    public var quotaError: Error?
    public var listPages: [BaiduPanFileListPage] = []
    private var listCallIndex = 0
    public private(set) var uploadedPaths: [String] = []
    public var uploadError: Error?
    public var uploadResult: BaiduPanUploadResult = BaiduPanUploadResult(fsId: 1, remotePath: "/apps/babycamera/backups/test.heic")

    public init() {}

    public func fetchQuota(accessToken: String) async throws -> BaiduPanQuotaInfo {
        if let quotaError { throw quotaError }
        _ = accessToken
        return quotaResult
    }

    public func listFiles(
        accessToken: String,
        directory: String,
        start: Int,
        limit: Int
    ) async throws -> BaiduPanFileListPage {
        _ = accessToken
        _ = directory
        _ = start
        _ = limit
        defer { listCallIndex += 1 }
        if listCallIndex < listPages.count {
            return listPages[listCallIndex]
        }
        return BaiduPanFileListPage(files: [])
    }

    public func uploadFile(
        accessToken: String,
        localFileURL: URL,
        remotePath: String,
        resumeState: BaiduPanMultipartState?,
        chunkSize: Int,
        onProgress: (@Sendable (Int64) -> Void)?
    ) async throws -> BaiduPanUploadResult {
        _ = accessToken
        _ = localFileURL
        _ = resumeState
        _ = chunkSize
        if let uploadError { throw uploadError }
        uploadedPaths.append(remotePath)
        onProgress?(Int64(chunkSize))
        return BaiduPanUploadResult(
            fsId: uploadResult.fsId,
            remotePath: remotePath,
            resumeState: uploadResult.resumeState
        )
    }
}
