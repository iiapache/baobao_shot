import Database
import Foundation

public enum PendingEngagementAction: Codable, Sendable, Equatable {
    case like(postId: String)
    case unlike(postId: String)
    case comment(postId: String, text: String, mentionUserIds: [String])
}

/// 离线互动积压队列，持久化到 `setting` 表。
public actor EngagementOfflineQueue {
    public static func storageKey(familyId: String) -> String {
        "feed.engagement.offline.\(familyId)"
    }

    private let familyId: String
    private let settingRepository: any SettingRepository
    private var pending: [PendingEngagementAction] = []
    private var loaded = false

    public init(familyId: String, settingRepository: any SettingRepository) {
        self.familyId = familyId
        self.settingRepository = settingRepository
    }

    public var count: Int {
        pending.count
    }

    public func enqueue(_ action: PendingEngagementAction) async throws {
        try await ensureLoaded()
        pending.append(action)
        try await persist()
    }

    public func dequeueAll() async throws -> [PendingEngagementAction] {
        try await ensureLoaded()
        let snapshot = pending
        pending.removeAll()
        try await persist()
        return snapshot
    }

    public func snapshot() async throws -> [PendingEngagementAction] {
        try await ensureLoaded()
        return pending
    }

    public func replaceAll(_ actions: [PendingEngagementAction]) async throws {
        try await ensureLoaded()
        pending = actions
        try await persist()
    }

    private func ensureLoaded() async throws {
        guard !loaded else { return }
        loaded = true
        guard let record = try await settingRepository.fetch(key: Self.storageKey(familyId: familyId)),
              let data = record.value.data(using: .utf8)
        else {
            pending = []
            return
        }
        pending = try JSONDecoder().decode([PendingEngagementAction].self, from: data)
    }

    private func persist() async throws {
        let data = try JSONEncoder().encode(pending)
        guard let value = String(data: data, encoding: .utf8) else { return }
        try await settingRepository.save(
            SettingRecord(key: Self.storageKey(familyId: familyId), value: value)
        )
    }
}
