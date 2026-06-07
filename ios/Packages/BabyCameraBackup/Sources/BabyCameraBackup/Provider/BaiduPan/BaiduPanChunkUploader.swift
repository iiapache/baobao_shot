import Foundation
import CryptoKit

/// 百度 superfile2 分片上传：precreate → upload(part) → create。
final class BaiduPanChunkUploader: @unchecked Sendable {
    private let transport: BaiduPanHTTPTransport
    private let configuration: BaiduPanOpenAPIConfiguration

    init(transport: BaiduPanHTTPTransport, configuration: BaiduPanOpenAPIConfiguration) {
        self.transport = transport
        self.configuration = configuration
    }

    func upload(
        accessToken: String,
        localFileURL: URL,
        remotePath: String,
        resumeState: BaiduPanMultipartState?,
        chunkSize: Int,
        onProgress: (@Sendable (Int64) -> Void)?
    ) async throws -> BaiduPanUploadResult {
        let fileData = try Data(contentsOf: localFileURL)
        let chunks = split(data: fileData, chunkSize: chunkSize)
        let blockList = chunks.map { md5Hex(of: $0) }

        var state = resumeState ?? try await precreate(
            accessToken: accessToken,
            remotePath: remotePath,
            fileSize: Int64(fileData.count),
            blockList: blockList
        )

        var uploadedBytes: Int64 = 0
        let completed = Set(state.completedPartIndexes)

        for (index, chunk) in chunks.enumerated() {
            if completed.contains(index) {
                uploadedBytes += Int64(chunk.count)
                continue
            }

            try await uploadPart(
                accessToken: accessToken,
                uploadId: state.uploadId,
                remotePath: remotePath,
                partIndex: index,
                data: chunk
            )
            state.completedPartIndexes.append(index)
            uploadedBytes += Int64(chunk.count)
            onProgress?(uploadedBytes)
        }

        let fsId = try await create(
            accessToken: accessToken,
            remotePath: remotePath,
            uploadId: state.uploadId,
            blockList: blockList,
            fileSize: Int64(fileData.count)
        )

        return BaiduPanUploadResult(fsId: fsId, remotePath: remotePath, resumeState: nil)
    }

    private func split(data: Data, chunkSize: Int) -> [Data] {
        guard !data.isEmpty else { return [Data()] }
        var chunks: [Data] = []
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            chunks.append(data.subdata(in: offset ..< end))
            offset = end
        }
        return chunks
    }

    private func md5Hex(of data: Data) -> String {
        Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func precreate(
        accessToken: String,
        remotePath: String,
        fileSize: Int64,
        blockList: [String]
    ) async throws -> BaiduPanMultipartState {
        var components = URLComponents(
            url: configuration.panBaseURL.appendingPathComponent("/rest/2.0/xpan/file"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "method", value: "precreate"),
            URLQueryItem(name: "access_token", value: accessToken),
        ]

        guard let url = components?.url else {
            throw BaiduPanProviderError.uploadFailed("invalid precreate url")
        }

        let body: [String: Any] = [
            "path": remotePath,
            "size": fileSize,
            "isdir": 0,
            "autoinit": 1,
            "rtype": 1,
            "block_list": blockList,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await transport.data(for: request)
        guard (200 ... 299).contains(response.statusCode) else {
            throw BaiduPanProviderError.openAPI(code: response.statusCode, message: "precreate failed")
        }

        let payload = try JSONDecoder().decode(BaiduPanPrecreateResponse.self, from: data)
        guard payload.errno == 0, let uploadId = payload.uploadid else {
            throw BaiduPanProviderError.openAPI(code: payload.errno, message: payload.errmsg ?? "precreate error")
        }

        return BaiduPanMultipartState(uploadId: uploadId, remotePath: remotePath)
    }

    private func uploadPart(
        accessToken: String,
        uploadId: String,
        remotePath: String,
        partIndex: Int,
        data: Data
    ) async throws {
        var components = URLComponents(
            url: configuration.pcsBaseURL.appendingPathComponent("/rest/2.0/pcs/superfile2"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "method", value: "upload"),
            URLQueryItem(name: "access_token", value: accessToken),
            URLQueryItem(name: "type", value: "tmpfile"),
            URLQueryItem(name: "path", value: remotePath),
            URLQueryItem(name: "uploadid", value: uploadId),
            URLQueryItem(name: "partseq", value: String(partIndex)),
        ]

        guard let url = components?.url else {
            throw BaiduPanProviderError.uploadFailed("invalid upload url")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await transport.data(for: request)
        guard (200 ... 299).contains(response.statusCode) else {
            throw BaiduPanProviderError.openAPI(code: response.statusCode, message: "chunk upload failed")
        }
    }

    private func create(
        accessToken: String,
        remotePath: String,
        uploadId: String,
        blockList: [String],
        fileSize: Int64
    ) async throws -> Int64 {
        var components = URLComponents(
            url: configuration.panBaseURL.appendingPathComponent("/rest/2.0/xpan/file"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "method", value: "create"),
            URLQueryItem(name: "access_token", value: accessToken),
        ]

        guard let url = components?.url else {
            throw BaiduPanProviderError.uploadFailed("invalid create url")
        }

        let body: [String: Any] = [
            "path": remotePath,
            "size": fileSize,
            "isdir": 0,
            "uploadid": uploadId,
            "block_list": blockList,
            "rtype": 1,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await transport.data(for: request)
        guard (200 ... 299).contains(response.statusCode) else {
            throw BaiduPanProviderError.openAPI(code: response.statusCode, message: "create failed")
        }

        let payload = try JSONDecoder().decode(BaiduPanCreateResponse.self, from: data)
        guard payload.errno == 0, let fsId = payload.fs_id else {
            throw BaiduPanProviderError.openAPI(code: payload.errno, message: payload.errmsg ?? "create error")
        }
        return fsId
    }
}

private struct BaiduPanPrecreateResponse: Decodable {
    let errno: Int
    let errmsg: String?
    let uploadid: String?
}

private struct BaiduPanCreateResponse: Decodable {
    let errno: Int
    let errmsg: String?
    let fs_id: Int64?
}
