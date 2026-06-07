import Foundation

/// 内置里程碑节点目录（PRD §4.8 / design-ios §4.8）。
public enum MilestoneCatalog {
    public static let minimumMilestoneCount = 10
    public static let manifestResourceName = MilestoneManifestLoader.catalogResourceName

    private static var catalogManifest: MilestoneCatalogManifest = loadCatalogManifest()

    public static var milestones: [MilestoneDefinition] {
        catalogManifest.milestones
            .map(MilestoneDefinition.init)
            .sorted { $0.sort < $1.sort }
    }

    private static var milestonesByID: [String: MilestoneDefinition] {
        Dictionary(uniqueKeysWithValues: milestones.map { ($0.id, $0) })
    }

    public static func milestone(for id: String) -> MilestoneDefinition? {
        milestonesByID[id]
    }

    public static var satisfiesMinimumCount: Bool {
        milestones.count >= minimumMilestoneCount
    }

    /// 单测重置 catalog。
    static func resetForTesting(manifest: MilestoneCatalogManifest? = nil) {
        if let manifest {
            catalogManifest = manifest
        } else {
            catalogManifest = loadCatalogManifest()
        }
    }

    private static func loadCatalogManifest() -> MilestoneCatalogManifest {
        do {
            return try MilestoneManifestLoader.loadCatalogFromBundle()
        } catch {
            assertionFailure("Milestone catalog manifest load failed: \(error)")
            return MilestoneCatalogManifest(schemaVersion: "0", milestones: [])
        }
    }
}
