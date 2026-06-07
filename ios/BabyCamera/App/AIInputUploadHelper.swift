import BabyCameraAIPlay
import BabyCameraNetwork
import CryptoKit
import Database
import Foundation

/// AI 任务输入图：从本地最新照片上传或 Mock 占位 objectKey（NAV-07）。
enum AIInputUploadHelper {
    struct PreparedInput: Sendable {
        let photoId: String
        let filePath: String
        let objectKey: String
    }

    static func prepare(
        babyId: String,
        userId: String,
        appDatabase: AppDatabase,
        client: APIClient,
        useMockShortcuts: Bool
    ) async throws -> PreparedInput {
        let photoRepository = appDatabase.makePhotoRepository()
        let photos = try await photoRepository.fetchByBaby(babyId: babyId, limit: 1)
        guard let latest = photos.first else {
            throw AIBootstrapError.missingSourcePhoto
        }

        if useMockShortcuts {
            return PreparedInput(
                photoId: latest.id,
                filePath: latest.filePath,
                objectKey: "ai-tmp/\(userId)/\(latest.id).heic"
            )
        }

        let fileURL = URL(fileURLWithPath: latest.filePath)
        let data = try Data(contentsOf: fileURL)
        let uploadService = UploadService(client: client)
        let result = try await uploadService.upload(
            purpose: .aiInput,
            items: [
                UploadPayloadItem(
                    clientRef: latest.id,
                    kind: "image",
                    mime: "image/heic",
                    data: data,
                    sha256: sha256Hex(data)
                ),
            ]
        )
        guard let item = result.items.first else {
            throw AIBootstrapError.uploadFailed
        }
        return PreparedInput(
            photoId: latest.id,
            filePath: latest.filePath,
            objectKey: item.objectKey
        )
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// UITest：将源图复制为 AI 结果，避免 mock CDN 返回无效 HEIC。
struct LocalCopyRemoteFileDownloader: RemoteFileDownloading, Sendable {
    let sourcePath: String

    func download(from source: URL, to destination: URL) async throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: URL(fileURLWithPath: sourcePath), to: destination)
    }
}
