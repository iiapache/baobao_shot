import Foundation

/// Client-side phase mapped from server task states (design-ios §9.1).
public enum AITaskPhase: String, Sendable, Equatable, Codable {
    case submitted
    case pending
    case running
    case succeeded
    case failed
    case rejected
    case appealed
    case downloaded

    public var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .rejected, .appealed, .downloaded:
            return true
        case .submitted, .pending, .running:
            return false
        }
    }
}

public enum AITaskPhaseMapper {
    public static func phase(forServerState state: String) -> AITaskPhase {
        switch state {
        case "created", "credit_held":
            return .submitted
        case "input_auditing", "queued":
            return .pending
        case "running", "output_auditing", "watermarking", "model_failed":
            return .running
        case "succeeded":
            return .succeeded
        case "failed":
            return .failed
        case "rejected":
            return .rejected
        case "appealed":
            return .appealed
        default:
            return .pending
        }
    }

    public static func isTerminalServerState(_ state: String) -> Bool {
        switch state {
        case "succeeded", "failed", "rejected", "appealed":
            return true
        default:
            return false
        }
    }
}
