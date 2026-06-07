import BabyCameraNetwork
import Foundation

public struct AITaskSnapshot: Sendable, Equatable {
    public let taskId: String
    public let phase: AITaskPhase
    public let serverState: String
    public let resultUrl: String?
    public let thumbnailUrl: String?
    public let deepSynth: AIDeepSynthMetadata?
    public let costCredits: Int?
    public let balanceAfter: Int?
    public let failureReason: String?
    public let updatedAt: Date

    public init(
        taskId: String,
        phase: AITaskPhase,
        serverState: String,
        resultUrl: String? = nil,
        thumbnailUrl: String? = nil,
        deepSynth: AIDeepSynthMetadata? = nil,
        costCredits: Int? = nil,
        balanceAfter: Int? = nil,
        failureReason: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.taskId = taskId
        self.phase = phase
        self.serverState = serverState
        self.resultUrl = resultUrl
        self.thumbnailUrl = thumbnailUrl
        self.deepSynth = deepSynth
        self.costCredits = costCredits
        self.balanceAfter = balanceAfter
        self.failureReason = failureReason
        self.updatedAt = updatedAt
    }

    init(
        taskId: String,
        detail: AITaskDetailData,
        updatedAt: Date = Date()
    ) {
        self.init(
            taskId: taskId,
            phase: AITaskPhaseMapper.phase(forServerState: detail.state),
            serverState: detail.state,
            resultUrl: detail.resultUrl,
            thumbnailUrl: detail.thumbnailUrl,
            deepSynth: detail.deepSynth,
            costCredits: detail.costCredits,
            balanceAfter: detail.balanceAfter,
            failureReason: detail.failureReason,
            updatedAt: updatedAt
        )
    }

    init(
        taskId: String,
        event: AITaskEvent,
        updatedAt: Date = Date()
    ) {
        self.init(
            taskId: taskId,
            phase: AITaskPhaseMapper.phase(forServerState: event.state),
            serverState: event.state,
            resultUrl: event.resultUrl,
            thumbnailUrl: event.thumbnailUrl,
            deepSynth: event.deepSynth,
            costCredits: event.costCredits,
            balanceAfter: event.balanceAfter,
            updatedAt: updatedAt
        )
    }

    init(
        created: AITaskCreatedData,
        updatedAt: Date = Date()
    ) {
        self.init(
            taskId: created.taskId,
            phase: AITaskPhaseMapper.phase(forServerState: created.state),
            serverState: created.state,
            costCredits: created.costCredits,
            balanceAfter: created.balanceAfter,
            updatedAt: updatedAt
        )
    }
}

/// Silent push payload for AI task completion (category `AI_DONE`).
public struct AITaskPushPayload: Sendable, Equatable, Decodable {
    public let taskId: String
    public let state: String
    public let resultUrl: String?
    public let thumbnailUrl: String?

    public init(
        taskId: String,
        state: String,
        resultUrl: String? = nil,
        thumbnailUrl: String? = nil
    ) {
        self.taskId = taskId
        self.state = state
        self.resultUrl = resultUrl
        self.thumbnailUrl = thumbnailUrl
    }
}
