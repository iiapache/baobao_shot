import BabyCameraImageKit
import BabyCameraNetwork
import CoreGraphics
import Database
import Foundation
import XCTest
@testable import BabyCameraAIPlay

final class AITaskResultDownloaderTests: XCTestCase {
    private var tempRoot: URL!
    private var appDatabase: AppDatabase!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("AITaskResultDownloaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        appDatabase = try AppDatabase.makeInMemory()
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
    }

    func testDownloadPersistsDerivedAndAITaskLocal() async throws {
        let payload = Data("result-image".utf8)
        let mock = MockRemoteFileDownloader(payload: payload)
        let downloader = makeDownloader(fileDownloader: mock)

        let request = makeRequest(taskId: "tsk_single_001", suffix: "a")
        let result = try await downloader.download(request)

        XCTAssertEqual(result.taskId, "tsk_single_001")
        XCTAssertEqual(result.derivedId, "tsk_single_001")
        XCTAssertEqual(result.derivedKind, .aiImage)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.filePath))

        let derived = try await appDatabase.makeDerivedRepository().fetch(id: "tsk_single_001")
        XCTAssertEqual(derived?.sourcePhotoId, "photo_a")
        XCTAssertEqual(derived?.type, DerivedAssetKind.aiImage.rawValue)

        let task = try await appDatabase.makeAITaskLocalRepository().fetch(id: "tsk_single_001")
        XCTAssertEqual(task?.state, "downloaded")
        XCTAssertEqual(task?.resultUrl, request.resultUrl)
        XCTAssertEqual(mock.downloadCount(for: request.resultUrl), 1)
    }

    func testDownloadRetriesAfterTransientFailure() async throws {
        let payload = Data("retry-image".utf8)
        let mock = MockRemoteFileDownloader(
            payload: payload,
            failUntilAttempt: 2
        )
        let downloader = makeDownloader(
            configuration: AITaskResultDownloaderConfiguration(
                maxRetries: 3,
                retryBaseDelay: 0.001,
                maxConcurrentDownloads: 1
            ),
            fileDownloader: mock
        )

        let request = makeRequest(taskId: "tsk_retry_001", suffix: "b")
        let result = try await downloader.download(request)

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.filePath))
        XCTAssertEqual(mock.downloadCount(for: request.resultUrl), 2)
    }

    func testDownloadFailsAfterMaxRetries() async throws {
        let mock = MockRemoteFileDownloader(payload: Data(), shouldAlwaysFail: true)
        let downloader = makeDownloader(
            configuration: AITaskResultDownloaderConfiguration(
                maxRetries: 2,
                retryBaseDelay: 0.001,
                maxConcurrentDownloads: 1
            ),
            fileDownloader: mock
        )

        let request = makeRequest(taskId: "tsk_fail_001", suffix: "c")

        do {
            _ = try await downloader.download(request)
            XCTFail("Expected download to fail")
        } catch let error as AITaskResultDownloaderError {
            XCTAssertEqual(error, .downloadFailed(taskId: "tsk_fail_001", attempts: 2))
        }

        XCTAssertNil(try await appDatabase.makeDerivedRepository().fetch(id: "tsk_fail_001"))
    }

    func testDownloadAllRunsConcurrentlyWithLimit() async throws {
        let mock = MockRemoteFileDownloader(
            payload: Data("batch".utf8),
            perDownloadDelay: 0.05
        )
        let downloader = makeDownloader(
            configuration: AITaskResultDownloaderConfiguration(
                maxRetries: 1,
                retryBaseDelay: 0.001,
                maxConcurrentDownloads: 2
            ),
            fileDownloader: mock
        )

        let requests = (1 ... 4).map { index in
            makeRequest(taskId: "tsk_batch_\(index)", suffix: "\(index)")
        }

        let startedAt = Date()
        let results = await downloader.downloadAll(requests)
        let elapsed = Date().timeIntervalSince(startedAt)

        XCTAssertEqual(results.count, 4)
        XCTAssertTrue(results.values.allSatisfy { result in
            if case .success = result { return true }
            return false
        })
        XCTAssertLessThan(elapsed, 0.18, "4 downloads with concurrency 2 should finish in ~2 waves")

        for request in requests {
            let derived = try await appDatabase.makeDerivedRepository().fetch(id: request.taskId)
            XCTAssertNotNil(derived)
            XCTAssertEqual(derived?.sourcePhotoId, request.context.sourcePhotoId)
        }
    }

    func testVideoDownloadUsesVideosDirectory() async throws {
        let payload = Data("video-bytes".utf8)
        let mock = MockRemoteFileDownloader(payload: payload)
        let thumbnailPath = tempRoot
            .appendingPathComponent("thumbnails/tsk_video_001_256.heic")
            .path
        let watermarkMock = MockAITaskResultWatermarkProcessor(
            videoThumbnailPath: thumbnailPath
        )
        let downloader = makeDownloader(
            fileDownloader: mock,
            watermarkProcessor: watermarkMock
        )

        let request = AITaskDownloadRequest(
            taskId: "tsk_video_001",
            resultUrl: "https://cdn.example/video.mp4",
            context: AITaskDownloadContext(
                sourcePhotoId: "photo_video",
                babyId: "baby_1",
                playKind: .video,
                style: "seedance",
                costCredits: 20,
                sourceUrl: "https://cdn.example/input.heic"
            )
        )

        let result = try await downloader.download(request)
        XCTAssertEqual(result.derivedKind, .aiVideo)
        XCTAssertTrue(result.filePath.contains("/videos/baby_1/"))
        XCTAssertTrue(result.filePath.hasSuffix(".mp4"))
        XCTAssertEqual(result.thumbnailPath, thumbnailPath)

        let derived = try await appDatabase.makeDerivedRepository().fetch(id: "tsk_video_001")
        XCTAssertTrue(derived?.specJSON?.contains("thumbnailPath") == true)
    }

    func testImageDownloadUsesSubscriptionAtWatermarkTime() async throws {
        let codec = ImageCodec()
        let image = TestImageFactory.makeSolidColorImage(width: 320, height: 240, color: .blue)
        let payload = try codec.encode(image: image, format: .jpeg).data
        let mock = MockRemoteFileDownloader(payload: payload)

        let subscriptionState = SubscriptionStateBox(isSubscribed: false)
        let watermarkProcessor = TrackingAITaskResultWatermarkProcessor()
        let downloader = makeDownloader(
            fileDownloader: mock,
            watermarkProcessor: watermarkProcessor,
            isSubscribed: { subscriptionState.isSubscribed }
        )

        subscriptionState.isSubscribed = true
        let request = makeRequest(taskId: "tsk_sub_toggle", suffix: "sub")
        _ = try await downloader.download(request)

        XCTAssertEqual(watermarkProcessor.lastIsSubscribed, true)
    }

    private func makeDownloader(
        configuration: AITaskResultDownloaderConfiguration = AITaskResultDownloaderConfiguration(),
        fileDownloader: MockRemoteFileDownloader,
        watermarkProcessor: any AITaskResultWatermarkProcessing = MockAITaskResultWatermarkProcessor(),
        isSubscribed: @escaping @Sendable () -> Bool = { false }
    ) -> AITaskResultDownloader {
        AITaskResultDownloader(
            configuration: configuration,
            storePaths: LocalStorePaths(storeRoot: tempRoot),
            fileDownloader: fileDownloader,
            watermarkProcessor: watermarkProcessor,
            isSubscribed: isSubscribed,
            aiTaskRepository: appDatabase.makeAITaskLocalRepository(),
            derivedRepository: appDatabase.makeDerivedRepository(),
            nowEpoch: { 1_700_000_000 }
        )
    }

    private func makeRequest(taskId: String, suffix: String) -> AITaskDownloadRequest {
        AITaskDownloadRequest(
            taskId: taskId,
            resultUrl: "https://cdn.example/\(taskId).heic",
            context: AITaskDownloadContext(
                sourcePhotoId: "photo_\(suffix)",
                babyId: "baby_1",
                playKind: .image,
                style: "cartoon",
                model: "seedream",
                costCredits: 8,
                sourceUrl: "https://cdn.example/input_\(suffix).heic"
            )
        )
    }
}

private final class MockRemoteFileDownloader: RemoteFileDownloading, @unchecked Sendable {
    private let lock = NSLock()
    private let payload: Data
    private let failUntilAttempt: Int
    private let shouldAlwaysFail: Bool
    private let perDownloadDelay: TimeInterval
    private var attemptsByURL: [String: Int] = [:]

    init(
        payload: Data,
        failUntilAttempt: Int = 0,
        shouldAlwaysFail: Bool = false,
        perDownloadDelay: TimeInterval = 0
    ) {
        self.payload = payload
        self.failUntilAttempt = failUntilAttempt
        self.shouldAlwaysFail = shouldAlwaysFail
        self.perDownloadDelay = perDownloadDelay
    }

    func download(from source: URL, to destination: URL) async throws {
        if perDownloadDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(perDownloadDelay * 1_000_000_000))
        }

        let attempt = incrementAttempt(for: source.absoluteString)
        if shouldAlwaysFail || attempt < failUntilAttempt {
            throw URLError(.cannotLoadFromNetwork)
        }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try payload.write(to: destination, options: .atomic)
    }

    func downloadCount(for url: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return attemptsByURL[url, default: 0]
    }

    private func incrementAttempt(for url: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let next = attemptsByURL[url, default: 0] + 1
        attemptsByURL[url] = next
        return next
    }
}

private struct MockAITaskResultWatermarkProcessor: AITaskResultWatermarkProcessing {
    var videoThumbnailPath: String?

    init(videoThumbnailPath: String? = nil) {
        self.videoThumbnailPath = videoThumbnailPath
    }

    func applyWatermarksToImageFile(at url: URL, isSubscribed: Bool) throws {}

    func generateVideoCoverThumbnail(
        videoURL: URL,
        derivedId: String,
        isSubscribed: Bool
    ) async throws -> String {
        videoThumbnailPath ?? "\(derivedId)-thumb.heic"
    }
}

private final class TrackingAITaskResultWatermarkProcessor: AITaskResultWatermarkProcessing, @unchecked Sendable {
    private(set) var lastIsSubscribed: Bool?

    func applyWatermarksToImageFile(at url: URL, isSubscribed: Bool) throws {
        lastIsSubscribed = isSubscribed
    }

    func generateVideoCoverThumbnail(
        videoURL: URL,
        derivedId: String,
        isSubscribed: Bool
    ) async throws -> String {
        lastIsSubscribed = isSubscribed
        return "\(derivedId)-thumb.heic"
    }
}

private final class SubscriptionStateBox: @unchecked Sendable {
    var isSubscribed: Bool

    init(isSubscribed: Bool) {
        self.isSubscribed = isSubscribed
    }
}

private enum TestImageFactory {
    static func makeSolidColorImage(width: Int, height: Int, color: CGColor) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}

private extension CGColor {
    static var blue: CGColor {
        CGColor(red: 0.1, green: 0.2, blue: 0.9, alpha: 1)
    }
}

final class AITaskResultDownloadCoordinatorTests: XCTestCase {
    func testCoordinatorDownloadsSucceededTaskAndMarksDownloaded() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("AITaskDownloadCoordinator-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let appDatabase = try AppDatabase.makeInMemory()
        let mock = MockRemoteFileDownloader(payload: Data("done".utf8))
        let downloader = AITaskResultDownloader(
            storePaths: LocalStorePaths(storeRoot: tempRoot),
            fileDownloader: mock,
            watermarkProcessor: MockAITaskResultWatermarkProcessor(),
            aiTaskRepository: appDatabase.makeAITaskLocalRepository(),
            derivedRepository: appDatabase.makeDerivedRepository(),
            nowEpoch: { 1_700_000_000 }
        )
        let downloadCoordinator = AITaskResultDownloadCoordinator(downloader: downloader)

        let webSocket = CoordinatorTestWebSocket()
        let fetcher = CoordinatorTestFetcher()
        let tokenStore = InMemoryTokenStore(access: "token", refresh: "refresh")
        let coordinator = AITaskCoordinator(
            taskFetcher: fetcher,
            webSocket: webSocket,
            tokenStore: tokenStore
        )

        await downloadCoordinator.register(
            taskId: "tsk_coord_001",
            context: AITaskDownloadContext(
                sourcePhotoId: "photo_coord",
                babyId: "baby_1",
                playKind: .image,
                style: "cartoon",
                sourceUrl: "https://cdn.example/input.heic"
            )
        )
        await downloadCoordinator.startObserving(coordinator)

        try await coordinator.track(
            created: AITaskCreatedData(
                taskId: "tsk_coord_001",
                state: "credit_held",
                costCredits: 8,
                balanceAfter: 92
            )
        )

        webSocket.emit(
            AITaskEvent(
                taskId: "tsk_coord_001",
                state: "succeeded",
                resultUrl: "https://cdn.example/tsk_coord_001.heic"
            )
        )

        try await waitUntil(timeout: 2) {
            await coordinator.snapshot(taskId: "tsk_coord_001")?.phase == .downloaded
        }

        let derived = try await appDatabase.makeDerivedRepository().fetch(id: "tsk_coord_001")
        XCTAssertNotNil(derived)
        XCTAssertEqual(derived?.sourcePhotoId, "photo_coord")

        await downloadCoordinator.stopObserving()
    }

    private func waitUntil(timeout: TimeInterval, condition: @escaping () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Condition not met before timeout")
    }
}

private final class CoordinatorTestFetcher: AITaskFetching, @unchecked Sendable {
    func fetchTask(taskId: String) async throws -> AITaskDetailData {
        AITaskDetailData(taskId: taskId, state: "running")
    }
}

private final class CoordinatorTestWebSocket: AITaskWebSocketConnecting, @unchecked Sendable {
    private let lock = NSLock()
    private var eventsContinuation: AsyncStream<AITaskEvent>.Continuation?
    private var connectionContinuation: AsyncStream<AIWebSocketConnectionState>.Continuation?

    lazy var events: AsyncStream<AITaskEvent> = {
        AsyncStream { continuation in
            lock.lock()
            eventsContinuation = continuation
            lock.unlock()
        }
    }()

    lazy var connectionStates: AsyncStream<AIWebSocketConnectionState> = {
        AsyncStream { continuation in
            lock.lock()
            connectionContinuation = continuation
            lock.unlock()
        }
    }()

    func connect(accessToken: String) {
        lock.lock()
        let continuation = connectionContinuation
        lock.unlock()
        continuation?.yield(.connected)
    }

    func disconnect() {}

    func subscribe(taskIds: [String]) async throws {}

    func emit(_ event: AITaskEvent) {
        lock.lock()
        let continuation = eventsContinuation
        lock.unlock()
        continuation?.yield(event)
    }
}
