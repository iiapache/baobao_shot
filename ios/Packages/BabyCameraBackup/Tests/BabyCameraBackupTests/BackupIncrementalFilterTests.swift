import XCTest
@testable import BabyCameraBackup

final class BackupIncrementalFilterTests: XCTestCase {
    func testFiltersAlreadyBackedUpSHA256() {
        let candidates = [
            makeCandidate(id: "p1", sha256: "hash-a", updatedAt: 100),
            makeCandidate(id: "p2", sha256: "hash-b", updatedAt: 200),
            makeCandidate(id: "p3", sha256: "hash-c", updatedAt: 300),
        ]

        let pending = BackupIncrementalFilter.pendingCandidates(
            candidates,
            backedUpHashes: ["hash-b"]
        )

        XCTAssertEqual(pending.map(\.photoId), ["p1", "p3"])
    }

    func testSortsByUpdatedAtAscending() {
        let candidates = [
            makeCandidate(id: "p3", sha256: "hash-c", updatedAt: 300),
            makeCandidate(id: "p1", sha256: "hash-a", updatedAt: 100),
            makeCandidate(id: "p2", sha256: "hash-b", updatedAt: 200),
        ]

        let pending = BackupIncrementalFilter.pendingCandidates(candidates, backedUpHashes: [])

        XCTAssertEqual(pending.map(\.photoId), ["p1", "p2", "p3"])
    }

    func testStableSortByPhotoIdWhenUpdatedAtEqual() {
        let candidates = [
            makeCandidate(id: "p-b", sha256: "hash-b", updatedAt: 100),
            makeCandidate(id: "p-a", sha256: "hash-a", updatedAt: 100),
        ]

        let pending = BackupIncrementalFilter.pendingCandidates(candidates, backedUpHashes: [])

        XCTAssertEqual(pending.map(\.photoId), ["p-a", "p-b"])
    }

    func testReturnsEmptyWhenAllHashesBackedUp() {
        let candidates = [
            makeCandidate(id: "p1", sha256: "hash-a", updatedAt: 100),
        ]

        let pending = BackupIncrementalFilter.pendingCandidates(
            candidates,
            backedUpHashes: ["hash-a"]
        )

        XCTAssertTrue(pending.isEmpty)
    }
}
