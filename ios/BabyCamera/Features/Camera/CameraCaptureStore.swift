import BabyCameraBaby
import BabyCameraCamera
import BabyCameraImageKit
import CoreImage
import Database
import Foundation

/// 相机 Tab 拍摄状态：PhotoCapturePipeline 落盘 + MetadataWriter 写入 `photo` 表。
@MainActor
final class CameraCaptureStore: ObservableObject {
    @Published private(set) var isCapturing = false
    @Published private(set) var savedPhotoCount = 0
    @Published private(set) var latestCapturedPhotoId: String?
    @Published var statusMessage: String?

    let session = CameraSession()

    private let metadataWriter: MetadataWriter
    private let originalsDirectory: URL

    init(appDatabase: AppDatabase) {
        metadataWriter = MetadataWriter(photoRepository: appDatabase.makePhotoRepository())
        originalsDirectory = CameraStorePaths.originalsDirectory
        try? FileManager.default.createDirectory(at: originalsDirectory, withIntermediateDirectories: true)
    }

    func capturePhoto(
        userId: String,
        baby: BabyProfile,
        overlayInfo: CameraOverlayInfo?
    ) async {
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }

        do {
            let pipeline = try session.makePhotoCapturePipeline(outputDirectory: originalsDirectory)
            let photoOut = try await pipeline.capturePhoto(overlayInfo: overlayInfo)
            let request = MetadataWriteRequest(
                photoOut: photoOut,
                babyIds: [baby.id],
                babies: [BabyMetadataInput(id: baby.id, birthDate: baby.birthDate)],
                userId: userId,
                captureTakenAtFallback: photoOut.capturedAt
            )
            let result = try await metadataWriter.write(request)
            savedPhotoCount += 1
            latestCapturedPhotoId = result.photoId
            statusMessage = "已保存照片 \(result.photoId.prefix(8))"
        } catch {
            statusMessage = "保存失败: \(error.localizedDescription)"
        }
    }

    /// UITest 主流程：无需真机摄像头，生成占位 JPEG 并写入 `photo` 表。
    func mockCapturePhoto(userId: String, baby: BabyProfile) async {
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }

        do {
            let photoID = UUID()
            let fileURL = originalsDirectory.appendingPathComponent("\(photoID.uuidString.prefix(8)).jpg")
            let image = Self.makeMockCGImage(seed: photoID.uuidString)
            let codec = ImageCodec()
            let encoded = try codec.encode(image: CIImage(cgImage: image), format: .jpeg)
            try encoded.data.write(to: fileURL, options: .atomic)

            let photoOut = PhotoOut(
                id: photoID,
                fileURL: fileURL,
                format: .jpeg,
                capturedAt: Date(),
                captureLatency: 0,
                didFallbackToJPEG: true
            )
            let request = MetadataWriteRequest(
                photoOut: photoOut,
                babyIds: [baby.id],
                babies: [BabyMetadataInput(id: baby.id, birthDate: baby.birthDate)],
                userId: userId,
                captureTakenAtFallback: photoOut.capturedAt
            )
            let result = try await metadataWriter.write(request)
            savedPhotoCount += 1
            latestCapturedPhotoId = result.photoId
            statusMessage = "已 mock 拍照 \(result.photoId.prefix(8))"
        } catch {
            statusMessage = "mock 拍照失败: \(error.localizedDescription)"
        }
    }

    private static func makeMockCGImage(seed: String) -> CGImage {
        let hash = seed.utf8.reduce(UInt8(0)) { ($0 &+ $1) }
        let red = CGFloat(hash % 200) / 255.0 + 0.2
        let green = CGFloat((hash / 3) % 200) / 255.0 + 0.2
        let blue = CGFloat((hash / 7) % 200) / 255.0 + 0.2
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 640,
            height: 480,
            bitsPerComponent: 8,
            bytesPerRow: 640 * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
        return context.makeImage()!
    }
}

enum CameraStorePaths {
    static var storeRoot: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BabyCameraStore", isDirectory: true)
    }

    static var originalsDirectory: URL {
        storeRoot.appendingPathComponent("originals", isDirectory: true)
    }
}
