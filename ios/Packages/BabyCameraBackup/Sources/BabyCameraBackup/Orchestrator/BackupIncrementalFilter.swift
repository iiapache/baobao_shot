import Foundation

/// 按 `photo.sha256` 增量去重，并按 `updatedAt` 升序排列（design-ios §12.2）。
public enum BackupIncrementalFilter {
    public static func pendingCandidates(
        _ candidates: [BackupPhotoCandidate],
        backedUpHashes: Set<String>
    ) -> [BackupPhotoCandidate] {
        candidates
            .filter { !backedUpHashes.contains($0.sha256) }
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt < rhs.updatedAt
                }
                return lhs.photoId < rhs.photoId
            }
    }
}
