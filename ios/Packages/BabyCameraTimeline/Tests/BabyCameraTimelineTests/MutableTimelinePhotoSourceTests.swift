import Database
import XCTest
@testable import BabyCameraTimeline

final class MutableTimelinePhotoSourceTests: XCTestCase {
    func testUpsertReplacesSameId() async throws {
        let source = MutableTimelinePhotoSource()
        let first = PhotoRecord(
            id: "p1",
            babyIds: ["baby_e2e"],
            userId: "u1",
            takenAt: 100,
            sha256: "a",
            filePath: "/tmp/a.jpg"
        )
        let updated = PhotoRecord(
            id: "p1",
            babyIds: ["baby_e2e"],
            userId: "u1",
            takenAt: 200,
            sha256: "b",
            filePath: "/tmp/b.jpg"
        )

        await source.upsert(first)
        await source.upsert(updated)

        let photos = try await source.fetchPhotos(babyId: "baby_e2e", before: nil, limit: 10)
        XCTAssertEqual(photos.count, 1)
        XCTAssertEqual(photos[0].sha256, "b")
    }

    func testAppendDistinctIds() async throws {
        let source = MutableTimelinePhotoSource()
        for index in 1...3 {
            await source.append(
                PhotoRecord(
                    id: "p\(index)",
                    babyIds: ["baby_e2e"],
                    userId: "u1",
                    takenAt: Int64(index * 100),
                    sha256: "h\(index)",
                    filePath: "/tmp/\(index).jpg"
                )
            )
        }

        let count = await source.photoCount(babyId: "baby_e2e")
        XCTAssertEqual(count, 3)
    }
}
