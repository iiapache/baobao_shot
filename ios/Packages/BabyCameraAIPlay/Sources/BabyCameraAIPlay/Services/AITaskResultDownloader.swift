import Database
import Foundation

public enum AITaskResultDownloaderError: Error, Equatable, Sendable {
    case invalidResultURL(String)
    case downloadFailed(taskId: String, attempts: Int)
    case persistenceFailed(taskId: String)
}

public protocol RemoteFileDownloading: Sendable {
    func download(from source: URL, to destination: URL) async throws
}

public struct URLSessionRemoteFileDownloader: RemoteFileDownloading, Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func download(from source: URL, to destination: URL) async throws {
        let (temporaryURL, response) = try await session.download(from: source)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: temporaryURL, to: destination)
    }
}

public struct AITaskResultDownloaderConfiguration: Sendable, Equatable {
    public var maxRetries: Int
    public var retryBaseDelay: TimeInterval
    public var maxConcurrentDownloads: Int

    public init(
        maxRetries: Int = 3,
        retryBaseDelay: TimeInterval = 0.5,
        maxConcurrentDownloads: Int = 3
    ) {
        self.maxRetries = maxRetries
        self.retryBaseDelay = retryBaseDelay
        self.maxConcurrentDownloads = max(1, maxConcurrentDownloads)
    }
}

public protocol AITaskResultDownloading: Sendable {
    func download(_ request: AITaskDownloadRequest) async throws -> AITaskDownloadResult
    func downloadAll(_ requests: [AITaskDownloadRequest]) async -> [String: Result<AITaskDownloadResult, Error>]
}

/// Downloads AI task results into `derived/` / `videos/` and persists `ai_task_local` + `derived` rows.
public actor AITaskResultDownloader: AITaskResultDownloading {
    private let configuration: AITaskResultDownloaderConfiguration
    private let storePaths: LocalStorePaths
    private let fileDownloader: any RemoteFileDownloading
    private let watermarkProcessor: any AITaskResultWatermarkProcessing
    private let isSubscribed: @Sendable () -> Bool
    private let aiTaskRepository: any AITaskLocalRepository
    private let derivedRepository: any DerivedRepository
    private let fileManager: FileManager
    private let clock: @Sendable () -> Date
    private let nowEpoch: @Sendable () -> Int64
    private let sleep: @Sendable (TimeInterval) async -> Void

    public init(
        configuration: AITaskResultDownloaderConfiguration = AITaskResultDownloaderConfiguration(),
        storePaths: LocalStorePaths,
        fileDownloader: any RemoteFileDownloading = URLSessionRemoteFileDownloader(),
        watermarkProcessor: any AITaskResultWatermarkProcessing? = nil,
        isSubscribed: @escaping @Sendable () -> Bool = { false },
        aiTaskRepository: any AITaskLocalRepository,
        derivedRepository: any DerivedRepository,
        fileManager: FileManager = .default,
        clock: @escaping @Sendable () -> Date = { Date() },
        nowEpoch: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970) },
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { interval in
            let nanoseconds = UInt64(max(0, interval) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.configuration = configuration
        self.storePaths = storePaths
        self.fileDownloader = fileDownloader
        self.watermarkProcessor = watermarkProcessor
            ?? AITaskResultWatermarkProcessor(storePaths: storePaths)
        self.isSubscribed = isSubscribed
        self.aiTaskRepository = aiTaskRepository
        self.derivedRepository = derivedRepository
        self.fileManager = fileManager
        self.clock = clock
        self.nowEpoch = nowEpoch
        self.sleep = sleep
    }

    public func download(_ request: AITaskDownloadRequest) async throws -> AITaskDownloadResult {
        guard let sourceURL = URL(string: request.resultUrl) else {
            throw AITaskResultDownloaderError.invalidResultURL(request.resultUrl)
        }

        let derivedKind = derivedKind(for: request.context.playKind)
        let derivedId = request.taskId
        let destination = try storePaths.ensureDirectory(
            for: storePaths.derivedFileURL(
                babyId: request.context.babyId,
                derivedId: derivedId,
                kind: derivedKind,
                date: clock()
            )
        )

        for attempt in 1 ... configuration.maxRetries {
            do {
                try await fileDownloader.download(from: sourceURL, to: destination)
                let thumbnailPath = try await applyPostDownloadWatermarks(
                    request: request,
                    destination: destination,
                    derivedKind: derivedKind,
                    derivedId: derivedId
                )
                return try await persistDownload(
                    request: request,
                    derivedId: derivedId,
                    derivedKind: derivedKind,
                    filePath: destination.path,
                    thumbnailPath: thumbnailPath
                )
            } catch {
                if attempt < configuration.maxRetries {
                    let delay = configuration.retryBaseDelay * pow(2.0, Double(attempt - 1))
                    await sleep(delay)
                }
            }
        }

        throw AITaskResultDownloaderError.downloadFailed(
            taskId: request.taskId,
            attempts: configuration.maxRetries
        )
    }

    public func downloadAll(_ requests: [AITaskDownloadRequest]) async -> [String: Result<AITaskDownloadResult, Error>] {
        guard !requests.isEmpty else { return [:] }

        var results: [String: Result<AITaskDownloadResult, Error>] = [:]
        results.reserveCapacity(requests.count)

        await withTaskGroup(of: (String, Result<AITaskDownloadResult, Error>).self) { group in
            var iterator = requests.makeIterator()
            var inFlight = 0

            func enqueueNext() {
                guard inFlight < configuration.maxConcurrentDownloads,
                      let request = iterator.next() else { return }
                inFlight += 1
                group.addTask {
                    do {
                        let result = try await self.download(request)
                        return (request.taskId, .success(result))
                    } catch {
                        return (request.taskId, .failure(error))
                    }
                }
            }

            for _ in 0 ..< min(configuration.maxConcurrentDownloads, requests.count) {
                enqueueNext()
            }

            for await (taskId, result) in group {
                results[taskId] = result
                inFlight -= 1
                enqueueNext()
            }
        }

        return results
    }

    private func applyPostDownloadWatermarks(
        request: AITaskDownloadRequest,
        destination: URL,
        derivedKind: DerivedAssetKind,
        derivedId: String
    ) async throws -> String? {
        let subscribed = isSubscribed()
        switch derivedKind {
        case .aiImage:
            try watermarkProcessor.applyWatermarksToImageFile(at: destination, isSubscribed: subscribed)
            return nil
        case .aiVideo:
            return try await watermarkProcessor.generateVideoCoverThumbnail(
                videoURL: destination,
                derivedId: derivedId,
                isSubscribed: subscribed
            )
        case .local:
            return nil
        }
    }

    private func persistDownload(
        request: AITaskDownloadRequest,
        derivedId: String,
        derivedKind: DerivedAssetKind,
        filePath: String,
        thumbnailPath: String?
    ) async throws -> AITaskDownloadResult {
        let timestamp = nowEpoch()
        let specJSON = makeSpecJSON(
            taskId: request.taskId,
            style: request.context.style,
            thumbnailPath: thumbnailPath
        )

        let derived = DerivedRecord(
            id: derivedId,
            sourcePhotoId: request.context.sourcePhotoId,
            type: derivedKind.rawValue,
            filePath: filePath,
            specJSON: specJSON,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        let taskRecord = AITaskLocalRecord(
            id: request.taskId,
            state: "downloaded",
            model: request.context.model,
            style: request.context.style,
            costCredits: request.context.costCredits,
            sourceUrl: request.context.sourceUrl,
            resultUrl: request.resultUrl,
            createdAt: timestamp
        )

        do {
            try await derivedRepository.save(derived)
            try await aiTaskRepository.save(taskRecord)
        } catch {
            if fileManager.fileExists(atPath: filePath) {
                try? fileManager.removeItem(atPath: filePath)
            }
            throw AITaskResultDownloaderError.persistenceFailed(taskId: request.taskId)
        }

        return AITaskDownloadResult(
            taskId: request.taskId,
            derivedId: derivedId,
            filePath: filePath,
            derivedKind: derivedKind,
            thumbnailPath: thumbnailPath
        )
    }

    private func derivedKind(for playKind: AIPlayKind) -> DerivedAssetKind {
        switch playKind {
        case .video:
            return .aiVideo
        case .image, .text:
            return .aiImage
        }
    }

    private func makeSpecJSON(taskId: String, style: String?, thumbnailPath: String? = nil) -> String {
        var payload: [String: String] = ["taskId": taskId]
        if let style, !style.isEmpty {
            payload["style"] = style
        }
        if let thumbnailPath, !thumbnailPath.isEmpty {
            payload["thumbnailPath"] = thumbnailPath
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"taskId":"\#(taskId)"}"#
        }
        return json
    }
}
