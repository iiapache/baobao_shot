import XCTest
@testable import BabyCameraNetwork

final class BabyAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testCreateBabySuccess() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/families/fam_test001/babies")
            return MockResponse(statusCode: 200, json: MockServer.babySuccessJSON())
        }

        let client = makeAuthenticatedClient(session: MockURLProtocol.makeSession())
        let api = BabyAPI(client: client)

        let result = try await api.create(
            familyId: "fam_test001",
            request: CreateBabyRequest(
                name: "豆豆",
                birthday: "2024-01-15",
                gender: "male",
                birthTime: "08:30"
            )
        )

        XCTAssertEqual(result.babyId, "bb_test001")
        XCTAssertEqual(result.name, "豆豆")
    }

    func testListBabiesSuccess() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/v1/families/fam_test001/babies")
            return MockResponse(statusCode: 200, json: MockServer.babyListSuccessJSON())
        }

        let client = makeAuthenticatedClient(session: MockURLProtocol.makeSession())
        let api = BabyAPI(client: client)

        let result = try await api.listByFamily(familyId: "fam_test001")
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].babyId, "bb_test001")
    }

    func testUpdateBabySuccess() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.url?.path, "/v1/babies/bb_test001")
            return MockResponse(statusCode: 200, json: MockServer.babySuccessJSON(name: "新名字"))
        }

        let client = makeAuthenticatedClient(session: MockURLProtocol.makeSession())
        let api = BabyAPI(client: client)

        let result = try await api.update(
            babyId: "bb_test001",
            request: UpdateBabyRequest(name: "新名字")
        )
        XCTAssertEqual(result.name, "新名字")
    }

    func testDeleteBabySuccess() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/v1/babies/bb_test001")
            return MockResponse(statusCode: 200, json: MockServer.babyDeleteSuccessJSON())
        }

        let client = makeAuthenticatedClient(session: MockURLProtocol.makeSession())
        let api = BabyAPI(client: client)

        let result = try await api.delete(babyId: "bb_test001")
        XCTAssertEqual(result.babyId, "bb_test001")
    }

    func testUploadAvatarSuccess() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/babies/bb_test001/avatar")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "image/jpeg")
            return MockResponse(statusCode: 200, json: MockServer.babyAvatarSuccessJSON())
        }

        let client = makeAuthenticatedClient(session: MockURLProtocol.makeSession())
        let api = BabyAPI(client: client)

        let result = try await api.uploadAvatar(
            babyId: "bb_test001",
            imageData: Data("jpeg-bytes".utf8)
        )
        XCTAssertEqual(result.babyId, "bb_test001")
        XCTAssertEqual(result.avatarUrl, "https://cdn.example.com/avatar/bb_test001.jpg")
    }
}
