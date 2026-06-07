import Foundation

// MARK: - Models

public struct AITaskSubmitParams: Encodable, Sendable, Equatable {
    public let duration: Int?
    public let aspectRatio: String?

    public init(duration: Int? = nil, aspectRatio: String? = nil) {
        self.duration = duration
        self.aspectRatio = aspectRatio
    }
}

public struct AITaskSubmitRequest: Encodable, Sendable, Equatable {
    public let play: String
    public let inputObjectKey: String
    public let familyId: String
    public let params: AITaskSubmitParams?

    public init(
        play: String,
        inputObjectKey: String,
        familyId: String,
        params: AITaskSubmitParams? = nil
    ) {
        self.play = play
        self.inputObjectKey = inputObjectKey
        self.familyId = familyId
        self.params = params
    }
}

public struct AITaskCreatedData: Decodable, Sendable, Equatable {
    public let taskId: String
    public let state: String
    public let costCredits: Int
    public let balanceAfter: Int
    public let estimatedSeconds: Int?

    public init(
        taskId: String,
        state: String,
        costCredits: Int,
        balanceAfter: Int,
        estimatedSeconds: Int? = nil
    ) {
        self.taskId = taskId
        self.state = state
        self.costCredits = costCredits
        self.balanceAfter = balanceAfter
        self.estimatedSeconds = estimatedSeconds
    }
}

public struct AITaskAppealRequest: Encodable, Sendable, Equatable {
    public let reason: String

    public init(reason: String) {
        self.reason = reason
    }
}

public struct AITaskAppealData: Decodable, Sendable, Equatable {
    public let taskId: String
    public let state: String
    public let appealId: String

    public init(taskId: String, state: String, appealId: String) {
        self.taskId = taskId
        self.state = state
        self.appealId = appealId
    }
}

public struct AITaskDetailData: Decodable, Sendable, Equatable {
    public let taskId: String
    public let state: String
    public let resultUrl: String?
    public let thumbnailUrl: String?
    public let deepSynth: AIDeepSynthMetadata?
    public let costCredits: Int?
    public let balanceAfter: Int?
    public let failureReason: String?

    public init(
        taskId: String,
        state: String,
        resultUrl: String? = nil,
        thumbnailUrl: String? = nil,
        deepSynth: AIDeepSynthMetadata? = nil,
        costCredits: Int? = nil,
        balanceAfter: Int? = nil,
        failureReason: String? = nil
    ) {
        self.taskId = taskId
        self.state = state
        self.resultUrl = resultUrl
        self.thumbnailUrl = thumbnailUrl
        self.deepSynth = deepSynth
        self.costCredits = costCredits
        self.balanceAfter = balanceAfter
        self.failureReason = failureReason
    }
}

// MARK: - Endpoint

enum AITasksEndpoint: Endpoint {
    case create(AITaskSubmitRequest)
    case get(taskId: String)
    case appeal(taskId: String, AITaskAppealRequest)

    var path: String {
        switch self {
        case .create:
            return "/v1/ai/tasks"
        case let .get(taskId):
            return "/v1/ai/tasks/\(taskId)"
        case let .appeal(taskId, _):
            return "/v1/ai/tasks/\(taskId)/appeal"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .create, .appeal:
            return .post
        case .get:
            return .get
        }
    }

    var headers: [String: String]? {
        ["Content-Type": "application/json; charset=utf-8"]
    }

    func encodeBody(with encoder: JSONEncoder) throws -> Data? {
        switch self {
        case let .create(body):
            return try encoder.encode(body)
        case let .appeal(_, body):
            return try encoder.encode(body)
        case .get:
            return nil
        }
    }
}

// MARK: - API

public struct AITasksAPI: Sendable {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /v1/ai/tasks
    public func createTask(_ request: AITaskSubmitRequest) async throws -> AITaskCreatedData {
        try await client.request(AITasksEndpoint.create(request))
    }

    /// GET /v1/ai/tasks/{taskId}
    public func getTask(taskId: String) async throws -> AITaskDetailData {
        try await client.request(AITasksEndpoint.get(taskId: taskId))
    }

    /// POST /v1/ai/tasks/{taskId}/appeal
    public func appealTask(taskId: String, reason: String) async throws -> AITaskAppealData {
        try await client.request(
            AITasksEndpoint.appeal(taskId: taskId, AITaskAppealRequest(reason: reason))
        )
    }
}
