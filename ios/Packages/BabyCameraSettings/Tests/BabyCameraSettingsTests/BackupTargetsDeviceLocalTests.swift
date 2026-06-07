import BabyCameraBackup
import BabyCameraNetwork
import XCTest
@testable import BabyCameraSettings

final class BackupTargetsDeviceLocalTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testBindICloudRunsAuthorizeAndPostsDeviceLocalToken() async throws {
        var capturedBody: Data?
        MockURLProtocol.register { request in
            if request.httpMethod == "POST", request.url?.path == "/v1/backup/providers" {
                capturedBody = request.httpBody
                return MockResponse(statusCode: 200, json: MockServer.backupProviderJSON(kind: "icloud"))
            }
            return MockResponse(statusCode: 404, json: ["error": "not found"])
        }

        let database = StubCloudKitPrivateDatabase()
        let service = makeService(iCloudProvider: ICloudProvider(database: database))

        _ = try await service.bindTarget(.iCloud)

        XCTAssertEqual(database.accountStatusCallCount, 1)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(capturedBody)) as? [String: Any])
        XCTAssertEqual(json["accessToken"] as? String, "device-local")
        XCTAssertEqual(json["kind"] as? String, "icloud")
        XCTAssertEqual((json["metadata"] as? [String: String])?["provider_mode"], "stub")
    }

    func testBindPhotosRunsAuthorizeAndPostsDeviceLocalToken() async throws {
        var capturedBody: Data?
        MockURLProtocol.register { request in
            if request.httpMethod == "POST", request.url?.path == "/v1/backup/providers" {
                capturedBody = request.httpBody
                return MockResponse(statusCode: 200, json: MockServer.backupProviderJSON(kind: "photos"))
            }
            return MockResponse(statusCode: 404, json: ["error": "not found"])
        }

        let permission = StubPhotosAddOnlyPermissionService(status: .authorized)
        let service = makeService(
            photosProvider: PhotosProvider(
                permission: permission,
                writer: StubPhotosLibraryWriter(),
                ledger: InMemoryPhotosWriteLedger()
            )
        )

        _ = try await service.bindTarget(.photos)

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(capturedBody)) as? [String: Any])
        XCTAssertEqual(json["kind"] as? String, "photos")
        XCTAssertEqual((json["metadata"] as? [String: String])?["provider_mode"], "stub")
    }

    func testBindICloudFailsWhenAccountUnavailable() async throws {
        MockURLProtocol.register { _ in
            MockResponse(statusCode: 404, json: ["error": "not found"])
        }

        let database = StubCloudKitPrivateDatabase(accountStatusResult: .noAccount)
        let service = makeService(iCloudProvider: ICloudProvider(database: database))

        do {
            _ = try await service.bindTarget(.iCloud)
            XCTFail("Expected iCloudUnavailable")
        } catch let error as ICloudProviderError {
            XCTAssertEqual(error, .iCloudUnavailable(.noAccount))
        }
    }

    func testBindPhotosFailsWhenAuthorizationDenied() async throws {
        MockURLProtocol.register { _ in
            MockResponse(statusCode: 404, json: ["error": "not found"])
        }

        let permission = StubPhotosAddOnlyPermissionService(status: .denied)
        let service = makeService(
            photosProvider: PhotosProvider(
                permission: permission,
                writer: StubPhotosLibraryWriter(),
                ledger: InMemoryPhotosWriteLedger()
            )
        )

        do {
            _ = try await service.bindTarget(.photos)
            XCTFail("Expected authorizationDenied")
        } catch let error as PhotosProviderError {
            XCTAssertEqual(error, .authorizationDenied)
        }
    }

    func testUnbindPhotosClearsLedger() async throws {
        MockURLProtocol.register { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/v1/backup/providers"):
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.backupProviderListJSON(items: [("bkp_photos", "photos")])
                )
            case ("DELETE", "/v1/backup/providers/bkp_photos"):
                return MockResponse(statusCode: 200, json: ["id": "bkp_photos"])
            default:
                return MockResponse(statusCode: 404, json: ["error": "not found"])
            }
        }

        let ledger = InMemoryPhotosWriteLedger()
        await ledger.record(item: BackupRemoteItem(remoteId: "asset-1", sha256: "hash-a"), byteSize: 100)
        let service = makeService(
            photosProvider: PhotosProvider(
                permission: StubPhotosAddOnlyPermissionService(),
                writer: StubPhotosLibraryWriter(),
                ledger: ledger
            )
        )

        try await service.unbindTarget(.photos)

        let page = await ledger.page(after: nil, limit: 10)
        XCTAssertTrue(page.items.isEmpty)
    }

    private func makeService(
        iCloudProvider: ICloudProvider? = nil,
        photosProvider: PhotosProvider? = nil
    ) -> BackupTargetsService {
        let tokenStore = InMemoryTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(
            tokenStore: tokenStore,
            session: MockURLProtocol.makeSession()
        )
        return BackupTargetsService(
            api: BackupAPI(client: client),
            baiduPanProvider: BaiduPanProvider.stub(),
            iCloudProvider: iCloudProvider,
            photosProvider: photosProvider
        )
    }
}
