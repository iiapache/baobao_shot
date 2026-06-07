import Database
import Foundation

/// In-memory implementation of `Database.BabyRepository` for tests and pre-GRDB sync (T1.19).
public final class InMemoryBabyRepository: BabyRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: BabyRecord] = [:]

    public init(seed: [BabyRecord] = []) {
        for record in seed {
            storage[record.id] = record
        }
    }

    public func fetchAll(familyId: String) async throws -> [BabyRecord] {
        lock.lock()
        defer { lock.unlock() }
        return storage.values
            .filter { $0.familyId == familyId }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func fetch(id: String) async throws -> BabyRecord? {
        lock.lock()
        defer { lock.unlock() }
        return storage[id]
    }

    public func save(_ baby: BabyRecord) async throws {
        lock.lock()
        defer { lock.unlock() }
        storage[baby.id] = baby
    }

    public func saveIfNewer(_ baby: BabyRecord) async throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if let existing = storage[baby.id],
           !SyncMerge.shouldApplyRemote(localUpdatedAt: existing.updatedAt, remoteUpdatedAt: baby.updatedAt) {
            return false
        }
        storage[baby.id] = baby
        return true
    }

    public func delete(id: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: id)
    }

    public func deleteByFamilyExcept(familyId: String, ids: Set<String>) async throws {
        lock.lock()
        defer { lock.unlock() }
        storage = storage.filter { key, value in
            value.familyId != familyId || ids.contains(key)
        }
    }
}
