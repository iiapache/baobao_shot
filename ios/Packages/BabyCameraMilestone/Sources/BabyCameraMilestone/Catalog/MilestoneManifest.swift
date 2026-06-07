import Foundation

// MARK: - Manifest decoding

struct MilestoneCatalogManifest: Codable, Sendable {
    var schemaVersion: String
    var taskRef: String?
    var description: String?
    var minAppVersion: String?
    var milestones: [MilestoneDefinitionRecord]
}

struct MilestoneDefinitionRecord: Codable, Sendable {
    var id: String
    var name: String
    var trigger: MilestoneTriggerRecord
    var notificationTitle: String
    var notificationBody: String
    var templateId: String?
    var sort: Int
}

struct MilestoneTriggerRecord: Codable, Sendable {
    var type: String
    var day: Int?
    var month: Int?
}

// MARK: - Domain models

public enum MilestoneTriggerKind: String, Codable, Sendable, Equatable {
    case dayOffset
    case annual
    case birthdayAnnual
}

public struct MilestoneTrigger: Sendable, Equatable {
    public var kind: MilestoneTriggerKind
    public var day: Int?
    public var month: Int?

    public init(kind: MilestoneTriggerKind, day: Int? = nil, month: Int? = nil) {
        self.kind = kind
        self.day = day
        self.month = month
    }

    init(record: MilestoneTriggerRecord) {
        switch record.type {
        case "dayOffset":
            self.kind = .dayOffset
            self.day = record.day
            self.month = nil
        case "annual":
            self.kind = .annual
            self.day = record.day
            self.month = record.month
        case "birthdayAnnual":
            self.kind = .birthdayAnnual
            self.day = nil
            self.month = nil
        default:
            self.kind = .dayOffset
            self.day = record.day
            self.month = record.month
        }
    }
}

public struct MilestoneDefinition: Identifiable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var trigger: MilestoneTrigger
    public var notificationTitle: String
    public var notificationBody: String
    public var templateId: String?
    public var sort: Int

    public init(
        id: String,
        name: String,
        trigger: MilestoneTrigger,
        notificationTitle: String,
        notificationBody: String,
        templateId: String? = nil,
        sort: Int = 0
    ) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.notificationTitle = notificationTitle
        self.notificationBody = notificationBody
        self.templateId = templateId
        self.sort = sort
    }

    init(record: MilestoneDefinitionRecord) {
        self.id = record.id
        self.name = record.name
        self.trigger = MilestoneTrigger(record: record.trigger)
        self.notificationTitle = record.notificationTitle
        self.notificationBody = record.notificationBody
        self.templateId = record.templateId
        self.sort = record.sort
    }
}
