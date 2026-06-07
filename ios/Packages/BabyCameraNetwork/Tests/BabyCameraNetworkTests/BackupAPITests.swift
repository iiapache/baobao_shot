import XCTest
@testable import BabyCameraNetwork

final class BackupAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testBindProvider() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/backup/providers")
            return MockResponse(statusCode: 200, json: MockServer.backupProviderJSON())
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = BackupAPI(client: client)

        let result = try await api.bindProvider(
            BindBackupProviderRequest(
                kind: "baidu_pan",
                accessToken: "baidu-access",
                refreshToken: "baidu-refresh",
                expiresAt: "2026-07-01T00:00:00Z",
                providerAccountId: "baidu-user-1",
                metadata: ["scope": "basic"]
            )
        )

        XCTAssertEqual(result.id, "bkp_test_001")
        XCTAssertEqual(result.kind, "baidu_pan")
        XCTAssertEqual(result.status, "active")
        XCTAssertEqual(result.providerAccountId, "baidu-user-1")
    }

    func testListProviders() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/v1/backup/providers")
            return MockResponse(
                statusCode: 200,
                json: MockServer.backupProviderListJSON(
                    items: [
                        ("bkp_test_001", "baidu_pan"),
                        ("bkp_test_002", "icloud"),
                    ]
                )
            )
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = BackupAPI(client: client)

        let result = try await api.listProviders()
        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.items[0].kind, "baidu_pan")
        XCTAssertEqual(result.items[1].kind, "icloud")
    }

    func testUnbindProvider() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/v1/backup/providers/bkp_test_001")
            return MockResponse(statusCode: 200, json: MockServer.backupUnbindJSON())
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = BackupAPI(client: client)

        let result = try await api.unbindProvider(id: "bkp_test_001")
        XCTAssertEqual(result.id, "bkp_test_001")
    }

    func testGetStatus() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/v1/backup/status")
            return MockResponse(
                statusCode: 200,
                json: MockServer.backupStatusJSON(
                    lastSuccessAt: "2026-06-06T09:00:00Z",
                    failureCount: 0
                )
            )
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = BackupAPI(client: client)

        let status = try await api.getStatus()
        XCTAssertEqual(status.failureCount, 0)
        XCTAssertEqual(status.lastSuccessAt, "2026-06-06T09:00:00Z")
    }

    func testReportStatusFailureThenSuccess() async throws {
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/backup/status" else { return nil }
            if request.httpMethod == "POST",
               let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               json["success"] as? Bool == false {
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.backupStatusJSON(
                        lastAttemptAt: "2026-06-06T08:00:00Z",
                        failureCount: 1,
                        lastErrorCode: "BACKUP_AUTH_REVOKED"
                    )
                )
            }
            return MockResponse(
                statusCode: 200,
                json: MockServer.backupStatusJSON(
                    lastSuccessAt: "2026-06-06T09:00:00Z",
                    lastAttemptAt: "2026-06-06T09:00:00Z",
                    failureCount: 0
                )
            )
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = BackupAPI(client: client)

        let failed = try await api.reportStatus(
            ReportBackupStatusRequest(
                success: false,
                attemptedAt: "2026-06-06T08:00:00Z",
                errorCode: "BACKUP_AUTH_REVOKED"
            )
        )
        XCTAssertEqual(failed.failureCount, 1)
        XCTAssertEqual(failed.lastErrorCode, "BACKUP_AUTH_REVOKED")

        let success = try await api.reportStatus(
            ReportBackupStatusRequest(
                success: true,
                attemptedAt: "2026-06-06T09:00:00Z"
            )
        )
        XCTAssertEqual(success.failureCount, 0)
        XCTAssertEqual(success.lastSuccessAt, "2026-06-06T09:00:00Z")
    }
}
