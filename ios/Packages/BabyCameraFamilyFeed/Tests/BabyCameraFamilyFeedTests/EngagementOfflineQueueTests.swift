import Database
import XCTest
@testable import BabyCameraFamilyFeed

final class EngagementOfflineQueueTests: XCTestCase {
    func testPersistAndReplaceQueue() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let settings = appDatabase.makeSettingRepository()
        let queue = EngagementOfflineQueue(familyId: "fam_001", settingRepository: settings)

        try await queue.enqueue(.like(postId: "pst_1"))
        try await queue.enqueue(.comment(postId: "pst_2", text: "hi", mentionUserIds: []))

        XCTAssertEqual(try await queue.snapshot().count, 2)

        let reopened = EngagementOfflineQueue(familyId: "fam_001", settingRepository: settings)
        XCTAssertEqual(try await reopened.snapshot().count, 2)

        try await reopened.replaceAll([.unlike(postId: "pst_1")])
        XCTAssertEqual(try await reopened.snapshot().count, 1)
    }
}
