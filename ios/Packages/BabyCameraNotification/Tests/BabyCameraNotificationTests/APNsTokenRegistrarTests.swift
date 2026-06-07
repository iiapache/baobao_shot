import BabyCameraNetwork
import XCTest
@testable import BabyCameraNotification

final class APNsTokenRegistrarTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testRegisterTokenSuccess() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/notifications/devices")
            return MockResponse(statusCode: 200, json: MockServer.registerDeviceJSON())
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))

        let registrar = APNsTokenRegistrar(
            tokenProvider: MockAPNsTokenProvider(token: Data([0x01, 0xab])),
            metadataProvider: MockDeviceMetadata(
                deviceId: "dev_test",
                appVersion: "1.0.0",
                osVersion: "iOS 17.5",
                model: "iPhone"
            ),
            tokenStore: tokenStore,
            clientFactory: { store in
                makeAuthenticatedClient(tokenStore: store, session: MockURLProtocol.makeSession())
            }
        )

        let result = try await registrar.registerToken(Data([0x01, 0xab]))
        XCTAssertEqual(result.deviceId, "dev_test_001")
    }

    func testRegisterCurrentTokenSkipsWhenMissing() async throws {
        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))

        let registrar = APNsTokenRegistrar(
            tokenProvider: MockAPNsTokenProvider(token: nil),
            metadataProvider: MockDeviceMetadata(
                deviceId: "dev_test",
                appVersion: "1.0.0",
                osVersion: "iOS 17.5",
                model: "iPhone"
            ),
            tokenStore: tokenStore
        )

        let result = try await registrar.registerCurrentTokenIfAvailable()
        XCTAssertNil(result)
    }

    func testUnregisterDevice() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/v1/notifications/devices/dev_test")
            return MockResponse(statusCode: 200, json: MockServer.emptySuccessJSON())
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))

        let registrar = APNsTokenRegistrar(
            tokenProvider: MockAPNsTokenProvider(),
            metadataProvider: MockDeviceMetadata(
                deviceId: "dev_test",
                appVersion: "1.0.0",
                osVersion: "iOS 17.5",
                model: "iPhone"
            ),
            tokenStore: tokenStore,
            clientFactory: { store in
                makeAuthenticatedClient(tokenStore: store, session: MockURLProtocol.makeSession())
            }
        )

        try await registrar.unregisterCurrentDevice()
    }

    func testTokenHexFormatting() {
        XCTAssertEqual(APNsTokenFormatter.hexString(from: Data([0x01, 0xab, 0xff])), "01abff")
    }
}
