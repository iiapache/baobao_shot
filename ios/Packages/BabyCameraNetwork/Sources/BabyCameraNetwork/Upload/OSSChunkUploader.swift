import Foundation

struct OSSLocation: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case mock(putURL: URL)
        case aliyun(endpoint: URL, bucket: String, objectKey: String)
    }

    let kind: Kind

    var isMock: Bool {
        if case .mock = kind { return true }
        return false
    }

    static func parse(uploadUrl: String, objectKey: String) throws -> OSSLocation {
        guard let url = URL(string: uploadUrl) else {
            throw UploadError.invalidUploadURL(uploadUrl)
        }
        if url.path.contains("/mock-oss/") || url.path.hasPrefix("/put/") {
            return OSSLocation(kind: .mock(putURL: url))
        }

        let pathParts = url.path.split(separator: "/").map(String.init)
        guard pathParts.count >= 2,
              let endpoint = URL(string: "\(url.scheme ?? "https")://\(url.host ?? "")") else {
            throw UploadError.invalidUploadURL(uploadUrl)
        }
        let bucket = pathParts[0]
        let key = pathParts.count > 1 ? pathParts.dropFirst().joined(separator: "/") : objectKey
        return OSSLocation(kind: .aliyun(endpoint: endpoint, bucket: bucket, objectKey: key))
    }
}

/// 分片上传状态，用于失败后续传
struct MultipartUploadState: Sendable, Equatable {
    let ossUploadId: String
    var completedParts: [Int: String]
}

protocol OSSUploadTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionOSSTransport: OSSUploadTransport {
    let session: URLSession

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkTransportError.invalidResponse
        }
        return (data, http)
    }
}

/// OSS 直传：单 PUT 或分片 multipart，含进度与重试
final class OSSChunkUploader: @unchecked Sendable {
    private let transport: OSSUploadTransport
    private let configuration: UploadConfiguration

    init(transport: OSSUploadTransport, configuration: UploadConfiguration = .default) {
        self.transport = transport
        self.configuration = configuration
    }

    convenience init(session: URLSession, configuration: UploadConfiguration = .default) {
        self.init(transport: URLSessionOSSTransport(session: session), configuration: configuration)
    }

    func upload(
        item: UploadInitItemData,
        data: Data,
        sts: STSCredentials?,
        resumeState: MultipartUploadState? = nil,
        bytesAlreadyUploaded: Int64 = 0,
        totalBytes: Int64,
        onProgress: (@Sendable (Int64) -> Void)?
    ) async throws -> MultipartUploadState? {
        let location = try OSSLocation.parse(uploadUrl: item.uploadUrl, objectKey: item.objectKey)

        switch location.kind {
        case let .mock(putURL):
            try await putWithRetry(
                url: putURL,
                data: data,
                headers: item.headers ?? [:],
                bytesAlreadyUploaded: bytesAlreadyUploaded,
                totalBytes: totalBytes,
                onProgress: onProgress
            )
            return nil

        case let .aliyun(endpoint, bucket, objectKey):
            guard let sts else { throw UploadError.missingSTSCredentials }
            let contentType = item.headers?["Content-Type"] ?? "application/octet-stream"

            if data.count <= configuration.multipartThreshold {
                let url = buildObjectURL(endpoint: endpoint, bucket: bucket, objectKey: objectKey)
                try await putWithRetry(
                    url: url,
                    data: data,
                    headers: signedPutHeaders(
                        bucket: bucket,
                        objectKey: objectKey,
                        contentType: contentType,
                        credentials: sts
                    ),
                    bytesAlreadyUploaded: bytesAlreadyUploaded,
                    totalBytes: totalBytes,
                    onProgress: onProgress
                )
                return nil
            }

            return try await multipartUpload(
                endpoint: endpoint,
                bucket: bucket,
                objectKey: objectKey,
                data: data,
                contentType: contentType,
                sts: sts,
                resumeState: resumeState,
                bytesAlreadyUploaded: bytesAlreadyUploaded,
                totalBytes: totalBytes,
                onProgress: onProgress
            )
        }
    }

    // MARK: - Single PUT

    private func putWithRetry(
        url: URL,
        data: Data,
        headers: [String: String],
        bytesAlreadyUploaded: Int64,
        totalBytes: Int64,
        onProgress: (@Sendable (Int64) -> Void)?
    ) async throws {
        var lastStatus: Int?
        for attempt in 1 ... configuration.maxRetries {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.httpBody = data
                headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

                let (_, response) = try await transport.data(for: request)
                guard (200 ... 299).contains(response.statusCode) else {
                    lastStatus = response.statusCode
                    throw UploadError.ossUploadFailed(statusCode: response.statusCode)
                }
                onProgress?(totalBytes)
                return
            } catch {
                lastStatus = (error as? UploadError).flatMap {
                    if case let .ossUploadFailed(code) = $0 { return code }
                    return nil
                }
                if attempt == configuration.maxRetries { break }
                try await sleepBeforeRetry(attempt: attempt)
            }
        }
        throw UploadError.exhaustedRetries(lastStatusCode: lastStatus)
    }

    private func signedPutHeaders(
        bucket: String,
        objectKey: String,
        contentType: String,
        credentials: STSCredentials
    ) -> [String: String] {
        OSSRequestSigner.signedHeaders(
            method: "PUT",
            bucket: bucket,
            objectKey: objectKey,
            contentType: contentType,
            credentials: credentials
        )
    }

    // MARK: - Multipart

    private func multipartUpload(
        endpoint: URL,
        bucket: String,
        objectKey: String,
        data: Data,
        contentType: String,
        sts: STSCredentials,
        resumeState: MultipartUploadState?,
        bytesAlreadyUploaded: Int64,
        totalBytes: Int64,
        onProgress: (@Sendable (Int64) -> Void)?
    ) async throws -> MultipartUploadState {
        var state = resumeState ?? MultipartUploadState(
            ossUploadId: try await initiateMultipart(
                endpoint: endpoint,
                bucket: bucket,
                objectKey: objectKey,
                sts: sts
            ),
            completedParts: [:]
        )

        let chunkSize = configuration.chunkSize
        let totalParts = (data.count + chunkSize - 1) / chunkSize
        var uploaded = bytesAlreadyUploaded

        for partNumber in 1 ... totalParts {
            if state.completedParts[partNumber] != nil {
                let start = (partNumber - 1) * chunkSize
                let end = min(start + chunkSize, data.count)
                uploaded = max(uploaded, Int64(end))
                onProgress?(uploaded)
                continue
            }

            let start = (partNumber - 1) * chunkSize
            let end = min(start + chunkSize, data.count)
            let chunk = data.subdata(in: start ..< end)

            let etag = try await uploadPartWithRetry(
                endpoint: endpoint,
                bucket: bucket,
                objectKey: objectKey,
                partNumber: partNumber,
                uploadId: state.ossUploadId,
                chunk: chunk,
                sts: sts
            )
            state.completedParts[partNumber] = etag
            uploaded = Int64(end)
            onProgress?(uploaded)
        }

        try await completeMultipartWithRetry(
            endpoint: endpoint,
            bucket: bucket,
            objectKey: objectKey,
            uploadId: state.ossUploadId,
            parts: state.completedParts,
            sts: sts
        )
        return state
    }

    private func initiateMultipart(
        endpoint: URL,
        bucket: String,
        objectKey: String,
        sts: STSCredentials
    ) async throws -> String {
        let url = buildObjectURL(
            endpoint: endpoint,
            bucket: bucket,
            objectKey: objectKey,
            query: [URLQueryItem(name: "uploads", value: nil)]
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let headers = OSSRequestSigner.signedHeaders(
            method: "POST",
            bucket: bucket,
            objectKey: objectKey,
            queryItems: [URLQueryItem(name: "uploads", value: nil)],
            credentials: sts
        )
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await transport.data(for: request)
        guard (200 ... 299).contains(response.statusCode) else {
            throw UploadError.multipartInitFailed
        }
        guard let uploadId = parseXMLTag(named: "UploadId", in: data) else {
            throw UploadError.multipartInitFailed
        }
        return uploadId
    }

    private func uploadPartWithRetry(
        endpoint: URL,
        bucket: String,
        objectKey: String,
        partNumber: Int,
        uploadId: String,
        chunk: Data,
        sts: STSCredentials
    ) async throws -> String {
        var lastStatus: Int?
        for attempt in 1 ... configuration.maxRetries {
            do {
                let query = [
                    URLQueryItem(name: "partNumber", value: String(partNumber)),
                    URLQueryItem(name: "uploadId", value: uploadId),
                ]
                let url = buildObjectURL(
                    endpoint: endpoint,
                    bucket: bucket,
                    objectKey: objectKey,
                    query: query
                )
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.httpBody = chunk
                let headers = OSSRequestSigner.signedHeaders(
                    method: "PUT",
                    bucket: bucket,
                    objectKey: objectKey,
                    queryItems: query,
                    credentials: sts
                )
                headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

                let (_, response) = try await transport.data(for: request)
                guard (200 ... 299).contains(response.statusCode) else {
                    lastStatus = response.statusCode
                    throw UploadError.ossUploadFailed(statusCode: response.statusCode)
                }
                let etag = response.value(forHTTPHeaderField: "ETag") ?? "\"\(partNumber)\""
                return etag
            } catch {
                lastStatus = (error as? UploadError).flatMap {
                    if case let .ossUploadFailed(code) = $0 { return code }
                    return nil
                }
                if attempt == configuration.maxRetries { break }
                try await sleepBeforeRetry(attempt: attempt)
            }
        }
        throw UploadError.exhaustedRetries(lastStatusCode: lastStatus)
    }

    private func completeMultipartWithRetry(
        endpoint: URL,
        bucket: String,
        objectKey: String,
        uploadId: String,
        parts: [Int: String],
        sts: STSCredentials
    ) async throws {
        let query = [URLQueryItem(name: "uploadId", value: uploadId)]
        let url = buildObjectURL(
            endpoint: endpoint,
            bucket: bucket,
            objectKey: objectKey,
            query: query
        )
        let body = buildCompleteMultipartXML(parts: parts)
        var lastStatus: Int?

        for attempt in 1 ... configuration.maxRetries {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = body
                var headers = OSSRequestSigner.signedHeaders(
                    method: "POST",
                    bucket: bucket,
                    objectKey: objectKey,
                    queryItems: query,
                    contentType: "application/xml",
                    credentials: sts
                )
                headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

                let (_, response) = try await transport.data(for: request)
                guard (200 ... 299).contains(response.statusCode) else {
                    lastStatus = response.statusCode
                    throw UploadError.multipartCompleteFailed
                }
                return
            } catch {
                if attempt == configuration.maxRetries { break }
                try await sleepBeforeRetry(attempt: attempt)
            }
        }
        throw UploadError.exhaustedRetries(lastStatusCode: lastStatus)
    }

    // MARK: - Helpers

    private func buildObjectURL(
        endpoint: URL,
        bucket: String,
        objectKey: String,
        query: [URLQueryItem] = []
    ) -> URL {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.path = "/\(bucket)/\(objectKey)"
        components.queryItems = query.isEmpty ? nil : query
        return components.url!
    }

    private func buildCompleteMultipartXML(parts: [Int: String]) -> Data {
        let sorted = parts.sorted { $0.key < $1.key }
        var xml = "<CompleteMultipartUpload>"
        for (number, etag) in sorted {
            let normalizedETag = etag.hasPrefix("\"") ? etag : "\"\(etag)\""
            xml += "<Part><PartNumber>\(number)</PartNumber><ETag>\(normalizedETag)</ETag></Part>"
        }
        xml += "</CompleteMultipartUpload>"
        return Data(xml.utf8)
    }

    private func parseXMLTag(named tag: String, in data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        guard let open = text.range(of: "<\(tag)>"),
              let close = text.range(of: "</\(tag)>") else { return nil }
        return String(text[open.upperBound ..< close.lowerBound])
    }

    private func sleepBeforeRetry(attempt: Int) async throws {
        let delay = configuration.retryBaseDelay * pow(2.0, Double(attempt - 1))
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
}
