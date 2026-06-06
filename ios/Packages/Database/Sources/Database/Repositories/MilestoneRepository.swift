import Foundation

public struct MilestoneRecord: Sendable, Equatable {
    public var id: String
    public var babyId: String
    public var name: String
    public var date: Int64
    public var kind: String
    public var reminded: Bool

    public init(
        id: String,
        babyId: String,
        name: String,
        date: Int64,
        kind: String,
        reminded: Bool = false
    ) {
        self.id = id
        self.babyId = babyId
        self.name = name
        self.date = date
        self.kind = kind
        self.reminded = reminded
    }
}

/// Custom + built-in milestone cache (`milestone` table).
public protocol MilestoneRepository: Sendable {
    func fetchByBaby(babyId: String) async throws -> [MilestoneRecord]
    func save(_ milestone: MilestoneRecord) async throws
    func delete(id: String) async throws
}
