import BabyCameraFamilyFeed
import BabyCameraNetwork
import CryptoKit
import Foundation

/// 发布前补齐媒体 objectKey：Mock 环境走占位 key，真机走 media-svc 上传。
enum FeedPostPublishHelper {
    static func ensureMediaReady(
        composer: PostComposerViewModel,
        client: APIClient,
        familyId: String,
        useMockShortcuts: Bool
    ) async throws {
        let pending = composer.mediaItems.filter { $0.objectKey == nil }
        guard !pending.isEmpty else { return }

        if useMockShortcuts {
            for item in pending {
                let ext = item.kind == .video ? "mov" : "heic"
                composer.updateObjectKey(
                    for: item.id,
                    objectKey: "family/\(familyId)/post/\(item.id).\(ext)"
                )
            }
            return
        }

        var payloads: [UploadPayloadItem] = []
        for item in pending {
            let data: Data
            let mime: String
            let kind: String

            switch item.kind {
            case .image:
                guard let previewData = item.previewData else { continue }
                data = previewData
                mime = "image/heic"
                kind = "image"
            case .video:
                guard let localURL = item.localURL else { continue }
                data = try Data(contentsOf: localURL)
                mime = "video/quicktime"
                kind = "video"
            }

            payloads.append(
                UploadPayloadItem(
                    clientRef: item.id,
                    kind: kind,
                    mime: mime,
                    data: data,
                    sha256: sha256Hex(data)
                )
            )
        }

        guard !payloads.isEmpty else { return }

        let uploadService = UploadService(client: client)
        let result = try await uploadService.upload(
            purpose: .postItem,
            familyId: familyId,
            items: payloads
        )

        for completeItem in result.items {
            composer.updateObjectKey(for: completeItem.clientRef, objectKey: completeItem.objectKey)
        }
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}