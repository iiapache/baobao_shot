import Foundation

public struct DerivedRecord: Sendable, Equatable {
    public var id: String
    public var sourcePhotoId: String
    public var type: String
    public var filePath: String
    public var specJSON: String?
    public var createdAt: Int64
    public var updatedAt: Int64

    public init(
        id: String,
        sourcePhotoId: String,
        type: String,
        filePath: String,
        specJSON: String? = nil,
        createdAt: Int64,
        updatedAt: Int64 = 0
    ) {
        self.id = id
        self.sourcePhotoId = sourcePhotoId
        self.type = type
        self.filePath = filePath
        self.specJSON = specJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Local cache for edited / AI-derived assets. GRDB implementation follows in T2.15+.
public protocol DerivedRepository: Sendable {
    func fetch(id: String) async throws -> DerivedRecord?
    func fetchBySourcePhoto(sourcePhotoId: String) async throws -> [DerivedRecord]
    func save(_ derived: DerivedRecord) async throws
    func delete(id: String) async throws
}
