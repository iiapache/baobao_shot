import Foundation

public enum MilestoneTimelineEntry: Identifiable, Sendable, Equatable {
    case builtin(MilestoneDefinition, triggerDate: Date)
    case custom(CustomMilestone)

    public var id: String {
        switch self {
        case let .builtin(definition, triggerDate):
            let dayKey = MilestoneDateCodec.dayKey(for: triggerDate)
            return "builtin.\(definition.id).\(dayKey)"
        case let .custom(milestone):
            return "custom.\(milestone.id)"
        }
    }
        switch self {
        case let .builtin(definition, _):
            return definition.name
        case let .custom(milestone):
            return milestone.name
        }
    }

    public var triggerDate: Date {
        switch self {
        case let .builtin(_, triggerDate):
            return triggerDate
        case let .custom(milestone):
            return milestone.date
        }
    }

    public var dayKey: String {
        dayKey(calendar: .current)
    }

    public func dayKey(calendar: Calendar) -> String {
        MilestoneDateCodec.dayKey(for: triggerDate, calendar: calendar)
    }

    public var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }

    public var templateId: String? {
        switch self {
        case let .builtin(definition, _):
            return definition.templateId
        case .custom:
            return nil
        }
    }

    public var builtinSort: Int? {
        switch self {
        case let .builtin(definition, _):
            return definition.sort
        case .custom:
            return nil
        }
    }
}
