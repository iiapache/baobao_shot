import BabyCameraNetwork
import Foundation

public struct CaptionGenerateInput: Sendable, Equatable {
    public let babyId: String
    public let babyName: String
    public let birthDate: String
    public let aiPlayId: String?
    public let aiPlayName: String?
    public let location: String?
    public let referenceDate: Date

    public init(
        babyId: String,
        babyName: String,
        birthDate: String,
        aiPlayId: String? = nil,
        aiPlayName: String? = nil,
        location: String? = nil,
        referenceDate: Date = Date()
    ) {
        self.babyId = babyId
        self.babyName = babyName
        self.birthDate = birthDate
        self.aiPlayId = aiPlayId
        self.aiPlayName = aiPlayName
        self.location = location
        self.referenceDate = referenceDate
    }
}

public enum CaptionGenerationOutcome: Equatable, Sendable {
    case success(candidates: [CaptionCandidate], remainingToday: Int)
    case dailyLimitExceeded(message: String, fallbackCaption: String)
    case degraded(fallbackCaption: String)
}

public protocol CaptionServing: Sendable {
    func generate(_ input: CaptionGenerateInput) async -> CaptionGenerationOutcome
}

/// 智能文案服务（T5.16）：调用 caption-svc，超限提示，失败时降级默认模板。
public struct CaptionService: CaptionServing {
    public static let dailyLimitMessage = "今日智能文案次数已用完，已为你填入默认文案"

    private let captionAPI: CaptionAPI

    public init(captionAPI: CaptionAPI) {
        self.captionAPI = captionAPI
    }

    public func generate(_ input: CaptionGenerateInput) async -> CaptionGenerationOutcome {
        let fallback = makeFallbackCaption(from: input)

        guard let ageDays = PostCaptionTemplate.growthDay(
            birthDate: input.birthDate,
            referenceDate: input.referenceDate
        ) else {
            return .degraded(fallbackCaption: fallback)
        }

        let request = CaptionGenerateRequest(
            babyId: input.babyId,
            ageDays: ageDays,
            play: input.aiPlayId,
            location: input.location
        )

        do {
            let data = try await captionAPI.generate(request)
            guard !data.candidates.isEmpty else {
                return .degraded(fallbackCaption: fallback)
            }
            return .success(
                candidates: data.candidates,
                remainingToday: data.remainingToday
            )
        } catch let apiError as APIError where apiError.code == .captionDailyLimit {
            return .dailyLimitExceeded(
                message: Self.dailyLimitMessage,
                fallbackCaption: fallback
            )
        } catch {
            return .degraded(fallbackCaption: fallback)
        }
    }

    private func makeFallbackCaption(from input: CaptionGenerateInput) -> String {
        PostCaptionTemplate.makeCaption(
            babyName: input.babyName,
            birthDate: input.birthDate,
            aiPlayName: input.aiPlayName,
            referenceDate: input.referenceDate
        )
    }
}
