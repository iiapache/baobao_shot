import BabyCameraNetwork
import Foundation

public struct CreditTransaction: Sendable, Equatable, Identifiable {
    public let id: String
    public let type: CreditTransactionType
    public let amount: Int
    public let refKind: String?
    public let refId: String?
    public let balanceAfter: Int
    public let createdAt: Date

    public init(
        id: String,
        type: CreditTransactionType,
        amount: Int,
        refKind: String? = nil,
        refId: String? = nil,
        balanceAfter: Int,
        createdAt: Date
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.refKind = refKind
        self.refId = refId
        self.balanceAfter = balanceAfter
        self.createdAt = createdAt
    }

    public init(item: CreditTransactionItem) {
        self.init(
            id: item.id,
            type: CreditTransactionType(rawValue: item.type),
            amount: item.amount,
            refKind: item.refKind,
            refId: item.refId,
            balanceAfter: item.balanceAfter,
            createdAt: CreditTransaction.parseCreatedAt(item.createdAt)
        )
    }

    public var title: String {
        type.displayTitle
    }

    public var amountText: String {
        if amount > 0 {
            return "+\(amount)"
        }
        return "\(amount)"
    }

    public var subtitle: String {
        let formatter = CreditTransaction.displayDateFormatter
        return "余额 \(balanceAfter) · \(formatter.string(from: createdAt))"
    }

    private static func parseCreatedAt(_ raw: String) -> Date {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw) ?? Date(timeIntervalSince1970: 0)
    }

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

public enum CreditTransactionType: String, Sendable, Equatable {
    case grant
    case charge
    case consume
    case refund
    case adjust
    case unknown

    public init(rawValue: String) {
        switch rawValue {
        case Self.grant.rawValue:
            self = .grant
        case Self.charge.rawValue:
            self = .charge
        case Self.consume.rawValue:
            self = .consume
        case Self.refund.rawValue:
            self = .refund
        case Self.adjust.rawValue:
            self = .adjust
        default:
            self = .unknown
        }
    }

    public var displayTitle: String {
        switch self {
        case .grant:
            return "积分发放"
        case .charge:
            return "积分充值"
        case .consume:
            return "积分消耗"
        case .refund:
            return "积分退还"
        case .adjust:
            return "积分调整"
        case .unknown:
            return "积分变动"
        }
    }
}

public struct CreditTransactionsPage: Sendable, Equatable {
    public let items: [CreditTransaction]
    public let nextCursor: String?

    public init(items: [CreditTransaction], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}
