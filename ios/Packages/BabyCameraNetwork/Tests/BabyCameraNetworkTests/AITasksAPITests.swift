import XCTest
@testable import BabyCameraNetwork

final class AITasksAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testCreateTask() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/ai/tasks")
            return MockResponse(statusCode: 200, json: MockServer.aiTaskCreatedJSON())
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = AITasksAPI(client: client)

        let result = try await api.createTask(
            AITaskSubmitRequest(
                play: "ghibli_kid",
                inputObjectKey: "ai-tmp/usr_test/photo.heic",
                familyId: "fam_test_001",
                params: AITaskSubmitParams(aspectRatio: "1:1")
            )
        )

        XCTAssertEqual(result.taskId, "tsk_test_001")
        XCTAssertEqual(result.state, "credit_held")
        XCTAssertEqual(result.costCredits, 8)
        XCTAssertEqual(result.balanceAfter, 92)
        XCTAssertEqual(result.estimatedSeconds, 18)
    }

    func testGetTask() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/v1/ai/tasks/tsk_test_001")
            return MockResponse(
                statusCode: 200,
                json: MockServer.aiTaskDetailJSON(
                    taskId: "tsk_test_001",
                    state: "succeeded",
                    resultUrl: "https://cdn.example/result.heic",
                    thumbnailUrl: "https://cdn.example/thumb.jpg"
                )
            )
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = AITasksAPI(client: client)

        let result = try await api.getTask(taskId: "tsk_test_001")

        XCTAssertEqual(result.taskId, "tsk_test_001")
        XCTAssertEqual(result.state, "succeeded")
        XCTAssertEqual(result.resultUrl, "https://cdn.example/result.heic")
        XCTAssertEqual(result.thumbnailUrl, "https://cdn.example/thumb.jpg")
    }

    func testAppealTask() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/ai/tasks/tsk_test_001/appeal")
            let body = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
            XCTAssertTrue(body?.contains("误判") == true)
            return MockResponse(statusCode: 200, json: MockServer.aiTaskAppealJSON())
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = AITasksAPI(client: client)

        let result = try await api.appealTask(taskId: "tsk_test_001", reason: "误判，内容为正常宝宝照片")

        XCTAssertEqual(result.taskId, "tsk_test_001")
        XCTAssertEqual(result.state, "appealed")
        XCTAssertEqual(result.appealId, "apl_test_001")
    }
}
