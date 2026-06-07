import Foundation

public enum AIWebSocketOp: String, Sendable, Codable {
    case subscribe
    case event
    case ping
    case pong
    case error
}

public struct AIWebSocketClientMessage: Encodable, Sendable, Equatable {
    public let op: AIWebSocketOp
    public let taskIds: [String]?

    public init(op: AIWebSocketOp, taskIds: [String]? = nil) {
        self.op = op
        self.taskIds = taskIds
    }

    public static func subscribe(taskIds: [String]) -> AIWebSocketClientMessage {
        AIWebSocketClientMessage(op: .subscribe, taskIds: taskIds)
    }

    public static let pong = AIWebSocketClientMessage(op: .pong)
}

public struct AIDeepSynthMetadata: Decodable, Sendable, Equatable {
    public let watermark: String?
    public let manifest: String?

    public init(watermark: String? = nil, manifest: String? = nil) {
        self.watermark = watermark
        self.manifest = manifest
    }
}

public struct AIWebSocketServerMessage: Decodable, Sendable, Equatable {
    public let op: AIWebSocketOp
    public let taskId: String?
    public let state: String?
    public let resultUrl: String?
    public let thumbnailUrl: String?
    public let deepSynth: AIDeepSynthMetadata?
    public let costCredits: Int?
    public let balanceAfter: Int?
    public let code: String?
    public let message: String?
}

public struct AITaskEvent: Sendable, Equatable {
    public let taskId: String
    public let state: String
    public let resultUrl: String?
    public let thumbnailUrl: String?
    public let deepSynth: AIDeepSynthMetadata?
    public let costCredits: Int?
    public let balanceAfter: Int?

    public init(
        taskId: String,
        state: String,
        resultUrl: String? = nil,
        thumbnailUrl: String? = nil,
        deepSynth: AIDeepSynthMetadata? = nil,
        costCredits: Int? = nil,
        balanceAfter: Int? = nil
    ) {
        self.taskId = taskId
        self.state = state
        self.resultUrl = resultUrl
        self.thumbnailUrl = thumbnailUrl
        self.deepSynth = deepSynth
        self.costCredits = costCredits
        self.balanceAfter = balanceAfter
    }

    init(message: AIWebSocketServerMessage) {
        self.init(
            taskId: message.taskId ?? "",
            state: message.state ?? "",
            resultUrl: message.resultUrl,
            thumbnailUrl: message.thumbnailUrl,
            deepSynth: message.deepSynth,
            costCredits: message.costCredits,
            balanceAfter: message.balanceAfter
        )
    }
}
