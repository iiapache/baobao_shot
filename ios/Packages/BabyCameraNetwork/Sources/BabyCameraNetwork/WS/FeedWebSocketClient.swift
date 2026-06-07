import Foundation

public enum FeedWebSocketConnectionState: Sendable, Equatable {
    case disconnected
    case connected
}

public enum FeedWebSocketClientError: Error, Equatable, Sendable {
    case missingAccessToken
    case invalidMessage
}

/// WebSocket client for `/v1/ws/feed` — heartbeat ping/pong + feed engagement deltas.
public final class FeedWebSocketClient: @unchecked Sendable {
    public struct Configuration: Sendable {
        public let region: AppRegion
        public let reconnectDelay: TimeInterval

        public init(region: AppRegion = .cn, reconnectDelay: TimeInterval = 1) {
            self.region = region
            self.reconnectDelay = reconnectDelay
        }
    }

    private let configuration: Configuration
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let stateLock = NSLock()

    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var subscribedFamilyIDs: Set<String> = []
    private var accessToken: String?
    private var shouldReconnect = false

    private var eventsContinuation: AsyncStream<FeedEngagementRemoteEvent>.Continuation?
    public private(set) lazy var events: AsyncStream<FeedEngagementRemoteEvent> = {
        AsyncStream(bufferingPolicy: .bufferingNewest(64)) { continuation in
            self.stateLock.lock()
            self.eventsContinuation = continuation
            self.stateLock.unlock()
        }
    }()

    private var connectionContinuation: AsyncStream<FeedWebSocketConnectionState>.Continuation?
    public private(set) lazy var connectionStates: AsyncStream<FeedWebSocketConnectionState> = {
        AsyncStream(bufferingPolicy: .bufferingNewest(8)) { continuation in
            self.stateLock.lock()
            self.connectionContinuation = continuation
            self.stateLock.unlock()
        }
    }()

    public init(configuration: Configuration = Configuration(), session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    deinit {
        disconnect()
        eventsContinuation?.finish()
        connectionContinuation?.finish()
    }

    public func connect(accessToken: String) {
        stateLock.lock()
        self.accessToken = accessToken
        self.shouldReconnect = true
        stateLock.unlock()
        openConnection()
    }

    public func disconnect() {
        stateLock.lock()
        shouldReconnect = false
        subscribedFamilyIDs.removeAll()
        accessToken = nil
        stateLock.unlock()

        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        emitConnectionState(.disconnected)
    }

    public func subscribe(familyIds: [String]) async throws {
        stateLock.lock()
        subscribedFamilyIDs.formUnion(familyIds)
        let ids = Array(subscribedFamilyIDs)
        stateLock.unlock()

        guard !ids.isEmpty else { return }
        try await send(FeedWebSocketClientMessage.subscribe(familyIds: ids))
    }

    private func openConnection() {
        stateLock.lock()
        guard shouldReconnect, let token = accessToken else {
            stateLock.unlock()
            return
        }
        let pendingSubscriptions = Array(subscribedFamilyIDs)
        stateLock.unlock()

        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)

        var components = URLComponents()
        components?.scheme = configuration.region.webSocketBaseURL.scheme
        components?.host = configuration.region.webSocketBaseURL.host
        components?.path = "/v1/ws/feed"
        components?.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components?.url else { return }

        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        emitConnectionState(.connected)

        receiveTask = Task { [weak self] in
            await self?.receiveLoop(on: task, resubscribe: pendingSubscriptions)
        }
    }

    private func receiveLoop(on task: URLSessionWebSocketTask, resubscribe: [String]) async {
        if !resubscribe.isEmpty {
            try? await Task.sleep(nanoseconds: 50_000_000)
            try? await subscribe(familyIds: resubscribe)
        }

        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                try await handle(message, on: task)
            } catch {
                if Task.isCancelled { return }
                emitConnectionState(.disconnected)
                stateLock.lock()
                let shouldRetry = shouldReconnect
                stateLock.unlock()
                guard shouldRetry else { return }
                try? await Task.sleep(
                    nanoseconds: UInt64(configuration.reconnectDelay * 1_000_000_000)
                )
                openConnection()
                return
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message, on task: URLSessionWebSocketTask) async throws {
        let data: Data
        switch message {
        case let .string(text):
            guard let encoded = text.data(using: .utf8) else {
                throw FeedWebSocketClientError.invalidMessage
            }
            data = encoded
        case let .data(encoded):
            data = encoded
        @unknown default:
            throw FeedWebSocketClientError.invalidMessage
        }

        let serverMessage = try decoder.decode(FeedWebSocketServerMessage.self, from: data)
        switch serverMessage.op {
        case .ping:
            try await send(.pong)
        case .event:
            if let event = FeedEngagementRemoteEvent(message: serverMessage) {
                eventsContinuation?.yield(event)
            }
        case .error:
            break
        case .subscribe, .pong:
            break
        }
    }

    private func send(_ message: FeedWebSocketClientMessage) async throws {
        guard let webSocketTask else { return }
        let data = try encoder.encode(message)
        guard let text = String(data: data, encoding: .utf8) else {
            throw FeedWebSocketClientError.invalidMessage
        }
        try await webSocketTask.send(.string(text))
    }

    private func emitConnectionState(_ state: FeedWebSocketConnectionState) {
        connectionContinuation?.yield(state)
    }
}
