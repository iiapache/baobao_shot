import Foundation

public enum AIWebSocketConnectionState: Sendable, Equatable {
    case disconnected
    case connected
}

public enum AIWebSocketClientError: Error, Equatable, Sendable {
    case missingAccessToken
    case invalidMessage
}

/// WebSocket client for `/v1/ws/ai` — heartbeat ping/pong + task event stream.
public final class AIWebSocketClient: @unchecked Sendable {
    public struct Configuration: Sendable {
        public let region: AppRegion
        public let reconnectDelay: TimeInterval
        public let messageIdleReconnect: TimeInterval

        public init(
            region: AppRegion = .cn,
            reconnectDelay: TimeInterval = 1,
            messageIdleReconnect: TimeInterval = 60
        ) {
            self.region = region
            self.reconnectDelay = reconnectDelay
            self.messageIdleReconnect = messageIdleReconnect
        }
    }

    private let configuration: Configuration
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let stateLock = NSLock()

    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var subscribedTaskIDs: Set<String> = []
    private var accessToken: String?
    private var shouldReconnect = false

    private var eventsContinuation: AsyncStream<AITaskEvent>.Continuation?
    public private(set) lazy var events: AsyncStream<AITaskEvent> = {
        AsyncStream(bufferingPolicy: .bufferingNewest(32)) { continuation in
            self.stateLock.lock()
            self.eventsContinuation = continuation
            self.stateLock.unlock()
        }
    }()

    private var connectionContinuation: AsyncStream<AIWebSocketConnectionState>.Continuation?
    public private(set) lazy var connectionStates: AsyncStream<AIWebSocketConnectionState> = {
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
        subscribedTaskIDs.removeAll()
        accessToken = nil
        stateLock.unlock()

        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        emitConnectionState(.disconnected)
    }

    public func subscribe(taskIds: [String]) async throws {
        stateLock.lock()
        subscribedTaskIDs.formUnion(taskIds)
        let ids = Array(subscribedTaskIDs)
        stateLock.unlock()

        guard !ids.isEmpty else { return }
        try await send(AIWebSocketClientMessage.subscribe(taskIds: ids))
    }

    private func openConnection() {
        stateLock.lock()
        guard shouldReconnect, let token = accessToken else {
            stateLock.unlock()
            return
        }
        let pendingSubscriptions = Array(subscribedTaskIDs)
        stateLock.unlock()

        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)

        var components = URLComponents()
        components?.scheme = configuration.region.webSocketBaseURL.scheme
        components?.host = configuration.region.webSocketBaseURL.host
        components?.path = "/v1/ws/ai"
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
            try? await subscribe(taskIds: resubscribe)
        }

        var lastMessageAt = Date()
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                lastMessageAt = Date()
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
                if Date().timeIntervalSince(lastMessageAt) >= configuration.messageIdleReconnect {
                    openConnection()
                    return
                }
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
                throw AIWebSocketClientError.invalidMessage
            }
            data = encoded
        case let .data(encoded):
            data = encoded
        @unknown default:
            throw AIWebSocketClientError.invalidMessage
        }

        let serverMessage = try decoder.decode(AIWebSocketServerMessage.self, from: data)
        switch serverMessage.op {
        case .ping:
            try await send(.pong)
        case .event:
            guard serverMessage.taskId != nil, serverMessage.state != nil else {
                throw AIWebSocketClientError.invalidMessage
            }
            eventsContinuation?.yield(AITaskEvent(message: serverMessage))
        case .error:
            break
        case .subscribe, .pong:
            break
        }
    }

    private func send(_ message: AIWebSocketClientMessage) async throws {
        guard let webSocketTask else { return }
        let data = try encoder.encode(message)
        guard let text = String(data: data, encoding: .utf8) else {
            throw AIWebSocketClientError.invalidMessage
        }
        try await webSocketTask.send(.string(text))
    }

    private func emitConnectionState(_ state: AIWebSocketConnectionState) {
        connectionContinuation?.yield(state)
    }
}
