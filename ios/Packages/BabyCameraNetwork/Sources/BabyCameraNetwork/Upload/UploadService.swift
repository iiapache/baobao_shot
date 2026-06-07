import Foundation

public typealias UploadProgressHandler = @Sendable (UploadProgress) -> Void

/// 根据 media-svc STS 凭据分片直传 OSS，含进度回调与失败重试/续传
public final class UploadService: @unchecked Sendable {
    private let uploadAPI: UploadAPI
    private let uploader: OSSChunkUploader

    public init(
        client: APIClient,
        uploadSession: URLSession = .shared,
        configuration: UploadConfiguration = .default
    ) {
        self.uploadAPI = UploadAPI(client: client)
        self.uploader = OSSChunkUploader(session: uploadSession, configuration: configuration)
    }

    /// 测试注入：自定义 OSS 传输层
    init(
        uploadAPI: UploadAPI,
        uploader: OSSChunkUploader
    ) {
        self.uploadAPI = uploadAPI
        self.uploader = uploader
    }

    /// 完整上传流程：init → OSS 直传（分片）→ complete
    public func upload(
        purpose: UploadPurpose,
        familyId: String? = nil,
        items: [UploadPayloadItem],
        onProgress: UploadProgressHandler? = nil
    ) async throws -> UploadResult {
        guard !items.isEmpty else {
            throw UploadError.itemCountMismatch
        }

        let initRequest = UploadInitRequest(
            purpose: purpose,
            familyId: familyId,
            items: items.map {
                UploadInitItemRequest(
                    clientRef: $0.clientRef,
                    kind: $0.kind,
                    mime: $0.mime,
                    size: $0.data.count,
                    sha256: $0.sha256
                )
            }
        )

        let initData = try await uploadAPI.initialize(initRequest)
        guard initData.items.count == items.count else {
            throw UploadError.itemCountMismatch
        }

        let dataByRef = Dictionary(uniqueKeysWithValues: items.map { ($0.clientRef, $0.data) })
        let totalBytes = Int64(items.reduce(0) { $0 + $1.data.count })
        var bytesUploaded: Int64 = 0

        for initItem in initData.items {
            guard let payload = dataByRef[initItem.clientRef] else {
                throw UploadError.missingItemData(clientRef: initItem.clientRef)
            }

            let itemOffset = bytesUploaded

            try await uploader.upload(
                item: initItem,
                data: payload,
                sts: initData.sts,
                resumeState: nil,
                bytesAlreadyUploaded: 0,
                totalBytes: Int64(payload.count)
            ) { itemBytes in
                let cumulative = itemOffset + itemBytes
                onProgress?(UploadProgress(bytesUploaded: cumulative, totalBytes: totalBytes))
            }

            bytesUploaded = itemOffset + Int64(payload.count)
            onProgress?(UploadProgress(bytesUploaded: bytesUploaded, totalBytes: totalBytes))
        }

        let completeData = try await uploadAPI.complete(
            UploadCompleteRequest(uploadId: initData.uploadId)
        )

        return UploadResult(
            uploadId: completeData.uploadId,
            status: completeData.status,
            items: completeData.items
        )
    }
}
