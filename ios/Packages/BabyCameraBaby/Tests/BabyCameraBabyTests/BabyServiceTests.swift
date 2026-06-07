import BabyCameraNetwork
import Database
import XCTest
@testable import BabyCameraBaby

final class BabyServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeService(
        repository: InMemoryBabyRepository = InMemoryBabyRepository(),
        familyId: String = "fam_test001"
    ) -> BabyService {
        BabyService(
            familyId: familyId,
            repository: repository,
            client: makeAuthenticatedClient(session: MockURLProtocol.makeSession())
        )
    }

    func testListBabiesSyncsRepository() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families/fam_test001/babies" {
                return MockResponse(statusCode: 200, json: MockServer.babyListSuccessJSON())
            }
            return nil
        }

        let repository = InMemoryBabyRepository()
        let service = makeService(repository: repository)

        let babies = try await service.listBabies()
        XCTAssertEqual(babies.count, 1)
        XCTAssertEqual(babies[0].name, "豆豆")

        let cached = try await repository.fetchAll(familyId: "fam_test001")
        XCTAssertEqual(cached.count, 1)
    }

    func testCreateBabyPersistsLocally() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families/fam_test001/babies" {
                return MockResponse(statusCode: 200, json: MockServer.babySuccessJSON(babyId: "bb_created"))
            }
            return nil
        }

        let repository = InMemoryBabyRepository()
        let service = makeService(repository: repository)
        let profile = BabyProfile(
            id: "local",
            familyId: "fam_test001",
            name: "新宝",
            birthDate: "2024-03-01"
        )

        let created = try await service.createBaby(profile)
        XCTAssertEqual(created.id, "bb_created")

        let cached = try await repository.fetch(id: "bb_created")
        XCTAssertEqual(cached?.name, "豆豆")
    }

    func testUploadAvatarUpdatesLocalCache() async throws {
        MockURLProtocol.register { request in
            switch request.url?.path {
            case "/v1/babies/bb_test001/avatar":
                return MockResponse(statusCode: 200, json: MockServer.babyAvatarSuccessJSON())
            default:
                return nil
            }
        }

        let repository = InMemoryBabyRepository(seed: [
            BabyRecord(id: "bb_test001", familyId: "fam_test001", name: "豆豆", birthDate: "2024-01-15"),
        ])
        let service = makeService(repository: repository)

        let updated = try await service.uploadAvatar(
            babyId: "bb_test001",
            imageData: Data("jpeg".utf8)
        )
        XCTAssertEqual(updated.avatarURL, "https://cdn.example.com/avatar/bb_test001.jpg")

        let cached = try await repository.fetch(id: "bb_test001")
        XCTAssertEqual(cached?.avatarPath, "https://cdn.example.com/avatar/bb_test001.jpg")
    }
}
