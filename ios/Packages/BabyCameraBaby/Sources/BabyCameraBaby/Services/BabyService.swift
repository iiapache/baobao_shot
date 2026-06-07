import BabyCameraNetwork
import Database
import Foundation

public enum BabyServiceError: Error, Equatable, Sendable {
    case missingFamilyId
    case babyNotFound
}

public struct BabyServiceConfiguration: Sendable {
    public let familyId: String
    public let repository: any BabyRepository
    public let clientFactory: @Sendable () -> APIClient

    public init(
        familyId: String,
        repository: any BabyRepository = InMemoryBabyRepository(),
        clientFactory: @escaping @Sendable () -> APIClient
    ) {
        self.familyId = familyId
        self.repository = repository
        self.clientFactory = clientFactory
    }
}

public final class BabyService: @unchecked Sendable {
    private let familyId: String
    private let repository: any BabyRepository
    private let clientFactory: @Sendable () -> APIClient

    public init(configuration: BabyServiceConfiguration) {
        self.familyId = configuration.familyId
        self.repository = configuration.repository
        self.clientFactory = configuration.clientFactory
    }

    public init(
        familyId: String,
        repository: any BabyRepository = InMemoryBabyRepository(),
        client: APIClient
    ) {
        self.familyId = familyId
        self.repository = repository
        self.clientFactory = { client }
    }

    private var api: BabyAPI {
        BabyAPI(client: clientFactory())
    }

    public func listBabies() async throws -> [BabyProfile] {
        let remote = try await api.listByFamily(familyId: familyId)
        for item in remote.items {
            let profile = BabyMapping.profile(from: item, fallbackFamilyId: familyId)
            try await repository.save(profile.toRecord())
        }
        let records = try await repository.fetchAll(familyId: familyId)
        return records.map(BabyProfile.init(record:))
    }

    public func getBaby(id: String) async throws -> BabyProfile {
        if let cached = try await repository.fetch(id: id) {
            return BabyProfile(record: cached)
        }

        let remote = try await api.get(babyId: id)
        let profile = BabyMapping.profile(from: remote, fallbackFamilyId: familyId)
        try await repository.save(profile.toRecord())
        return profile
    }

    @discardableResult
    public func createBaby(_ profile: BabyProfile) async throws -> BabyProfile {
        guard !familyId.isEmpty else { throw BabyServiceError.missingFamilyId }

        let remote = try await api.create(
            familyId: familyId,
            request: BabyMapping.createRequest(from: profile)
        )
        var saved = BabyMapping.profile(from: remote, fallbackFamilyId: familyId)
        saved.updatedAt = Int64(Date().timeIntervalSince1970)
        try await repository.save(saved.toRecord())
        return saved
    }

    @discardableResult
    public func updateBaby(_ profile: BabyProfile) async throws -> BabyProfile {
        let remote = try await api.update(
            babyId: profile.id,
            request: BabyMapping.updateRequest(from: profile)
        )
        var saved = BabyMapping.profile(from: remote, fallbackFamilyId: familyId)
        saved.updatedAt = Int64(Date().timeIntervalSince1970)
        try await repository.save(saved.toRecord())
        return saved
    }

    public func deleteBaby(id: String) async throws {
        _ = try await api.delete(babyId: id)
        try await repository.delete(id: id)
    }

    @discardableResult
    public func uploadAvatar(babyId: String, imageData: Data, contentType: String = "image/jpeg") async throws -> BabyProfile {
        let result = try await api.uploadAvatar(
            babyId: babyId,
            imageData: imageData,
            contentType: contentType
        )

        guard var existing = try await repository.fetch(id: babyId).map(BabyProfile.init(record:)) else {
            let remote = try await api.get(babyId: babyId)
            var profile = BabyMapping.profile(from: remote, fallbackFamilyId: familyId)
            profile.avatarURL = result.avatarUrl
            profile.updatedAt = Int64(Date().timeIntervalSince1970)
            try await repository.save(profile.toRecord())
            return profile
        }

        existing.avatarURL = result.avatarUrl
        existing.updatedAt = Int64(Date().timeIntervalSince1970)
        try await repository.save(existing.toRecord())
        return existing
    }
}
