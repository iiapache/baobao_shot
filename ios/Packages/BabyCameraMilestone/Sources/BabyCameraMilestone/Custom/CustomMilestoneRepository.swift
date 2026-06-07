import Database
import Foundation

public protocol CustomMilestoneRepository: Sendable {
    func fetchAll(babyId: String) async throws -> [CustomMilestone]
    func fetch(id: String) async throws -> CustomMilestone?
    func create(babyId: String, name: String, date: Date) async throws -> CustomMilestone
    func update(_ milestone: CustomMilestone) async throws
    func delete(id: String) async throws
}

public struct GRDBCustomMilestoneRepository: CustomMilestoneRepository {
    private let repository: any MilestoneRepository
    private let idGenerator: @Sendable () -> String

    public init(
        repository: any MilestoneRepository,
        idGenerator: @escaping @Sendable () -> String = {
            "ms_custom_\(UUID().uuidString.lowercased())"
        }
    ) {
        self.repository = repository
        self.idGenerator = idGenerator
    }

    public func fetchAll(babyId: String) async throws -> [CustomMilestone] {
        try await repository
            .fetchByBaby(babyId: babyId)
            .filter { $0.recordKind == .custom }
            .map(mapRecord(_:))
    }

    public func fetch(id: String) async throws -> CustomMilestone? {
        guard let record = try await repository.fetch(id: id),
              record.recordKind == .custom else {
            return nil
        }
        return mapRecord(record)
    }

    public func create(babyId: String, name: String, date: Date) async throws -> CustomMilestone {
        let milestone = CustomMilestone(
            id: idGenerator(),
            babyId: babyId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date
        )
        try await repository.save(mapMilestone(milestone))
        return milestone
    }

    public func update(_ milestone: CustomMilestone) async throws {
        try await repository.save(mapMilestone(milestone))
    }

    public func delete(id: String) async throws {
        try await repository.delete(id: id)
    }

    private func mapRecord(_ record: MilestoneRecord) -> CustomMilestone {
        CustomMilestone(
            id: record.id,
            babyId: record.babyId,
            name: record.name,
            date: MilestoneDateCodec.date(fromTimestamp: record.date),
            reminded: record.reminded
        )
    }

    private func mapMilestone(_ milestone: CustomMilestone) -> MilestoneRecord {
        MilestoneRecord(
            id: milestone.id,
            babyId: milestone.babyId,
            name: milestone.name,
            date: MilestoneDateCodec.startOfDayTimestamp(for: milestone.date),
            kind: MilestoneRecordKind.custom.rawValue,
            reminded: milestone.reminded
        )
    }
}
