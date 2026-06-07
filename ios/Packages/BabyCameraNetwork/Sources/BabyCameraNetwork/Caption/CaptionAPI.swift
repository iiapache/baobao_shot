import Foundation

// MARK: - Models

public struct CaptionGenerateRequest: Encodable, Sendable, Equatable {
    public let babyId: String
    public let ageDays: Int
    public let play: String?
    public let location: String?

    public init(
        babyId: String,
        ageDays: Int,
        play: String? = nil,
        location: String? = nil
    ) {
        self.babyId = babyId
        self.ageDays = ageDays
        self.play = play
        self.location = location
    }
}

public struct CaptionCandidate: Decodable, Sendable, Equatable, Identifiable {
    public let text: String
    public let hashtags: [String]

    public var id: String { text }

    public init(text: String, hashtags: [String] = []) {
        self.text = text
        self.hashtags = hashtags
    }

    /// 发布文案：正文 + 空格分隔的话题词。
    public var composedText: String {
        let tags = hashtags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !tags.isEmpty else { return text }
        return "\(text) \(tags.joined(separator: " "))"
    }
}

public struct CaptionGenerateData: Decodable, Sendable, Equatable {
    public let candidates: [CaptionCandidate]
    public let remainingToday: Int

    public init(candidates: [CaptionCandidate], remainingToday: Int) {
        self.candidates = candidates
        self.remainingToday = remainingToday
    }
}

// MARK: - Endpoint

enum CaptionEndpoint: Endpoint {
    case generate(CaptionGenerateRequest)

    var path: String {
        switch self {
        case .generate:
            return "/v1/caption/generate"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .generate:
            return .post
        }
    }

    func encodeBody(with encoder: JSONEncoder) throws -> Data? {
        switch self {
        case let .generate(request):
            return try encoder.encode(request)
        }
    }
}

// MARK: - API

public struct CaptionAPI: Sendable {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /v1/caption/generate
    public func generate(_ request: CaptionGenerateRequest) async throws -> CaptionGenerateData {
        try await client.request(CaptionEndpoint.generate(request))
    }
}
