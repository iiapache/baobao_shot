import Foundation

/// Terminal failure categories for AI task UI (T3.23).
public enum AITaskFailureKind: String, Sendable, Equatable {
    /// Model retries exhausted (`failed`).
    case modelFailed
    /// Audit rejection (`rejected`).
    case rejected
    /// Appeal submitted (`appealed`).
    case appealed
}

public struct AITaskCreditRefundInfo: Sendable, Equatable {
    public let refundedCredits: Int
    public let balanceAfter: Int

    public init(refundedCredits: Int, balanceAfter: Int) {
        self.refundedCredits = refundedCredits
        self.balanceAfter = balanceAfter
    }

    public var message: String {
        "已退还 \(refundedCredits) 积分，当前余额 \(balanceAfter) 积分"
    }
}

public struct AITaskFailurePresentation: Sendable, Equatable {
    public let kind: AITaskFailureKind
    public let title: String
    public let message: String
    public let creditRefund: AITaskCreditRefundInfo?
    public let canAppeal: Bool

    public init(
        kind: AITaskFailureKind,
        title: String,
        message: String,
        creditRefund: AITaskCreditRefundInfo? = nil,
        canAppeal: Bool = false
    ) {
        self.kind = kind
        self.title = title
        self.message = message
        self.creditRefund = creditRefund
        self.canAppeal = canAppeal
    }
}

public enum AITaskOutcomeMapper {
    public static func failureKind(forServerState state: String) -> AITaskFailureKind? {
        switch state {
        case "failed":
            return .modelFailed
        case "rejected":
            return .rejected
        case "appealed":
            return .appealed
        default:
            return nil
        }
    }

    public static func creditRefund(from snapshot: AITaskSnapshot) -> AITaskCreditRefundInfo? {
        guard let costCredits = snapshot.costCredits,
              let balanceAfter = snapshot.balanceAfter,
              costCredits > 0 else {
            return nil
        }
        guard failureKind(forServerState: snapshot.serverState) != nil else {
            return nil
        }
        return AITaskCreditRefundInfo(refundedCredits: costCredits, balanceAfter: balanceAfter)
    }

    public static func presentation(for snapshot: AITaskSnapshot) -> AITaskFailurePresentation? {
        guard let kind = failureKind(forServerState: snapshot.serverState) else {
            return nil
        }

        let refund = creditRefund(from: snapshot)
        let reason = snapshot.failureReason?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch kind {
        case .modelFailed:
            return AITaskFailurePresentation(
                kind: kind,
                title: "生成失败",
                message: reason?.isEmpty == false ? reason! : "生成失败，请稍后重试",
                creditRefund: refund,
                canAppeal: false
            )
        case .rejected:
            return AITaskFailurePresentation(
                kind: kind,
                title: "内容未通过审核",
                message: reason?.isEmpty == false ? reason! : "该内容不符合社区规范",
                creditRefund: refund,
                canAppeal: true
            )
        case .appealed:
            return AITaskFailurePresentation(
                kind: kind,
                title: "申诉已提交",
                message: "我们已收到你的申诉，将在 24 小时内处理",
                creditRefund: refund,
                canAppeal: false
            )
        }
    }
}
