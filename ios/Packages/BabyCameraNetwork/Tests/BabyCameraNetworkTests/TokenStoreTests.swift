import XCTest
@testable import BabyCameraNetwork

final class TokenStoreTests: XCTestCase {
    override func tearDown() {
        KeychainTokenStore(service: testService).clear()
        super.tearDown()
    }

    private var testService: String {
        "com.babycamera.tests.\(name)"
    }

    func testInMemoryTokenStoreRoundTrip() {
        let store = InMemoryTokenStore()
        XCTAssertNil(store.accessToken())
        XCTAssertNil(store.refreshToken())

        store.save(TokenPair(accessToken: "access-1", refreshToken: "refresh-1"))
        XCTAssertEqual(store.accessToken(), "access-1")
        XCTAssertEqual(store.refreshToken(), "refresh-1")

        store.clear()
        XCTAssertNil(store.accessToken())
        XCTAssertNil(store.refreshToken())
    }

    func testKeychainTokenStoreRoundTrip() {
        let store = KeychainTokenStore(service: testService)
        store.clear()

        store.save(
            TokenPair(
                accessToken: "kc-access",
                refreshToken: "kc-refresh",
                accessTokenExpiresIn: 3600,
                refreshTokenExpiresIn: 2_592_000
            )
        )

        XCTAssertEqual(store.accessToken(), "kc-access")
        XCTAssertEqual(store.refreshToken(), "kc-refresh")

        let reloaded = KeychainTokenStore(service: testService)
        XCTAssertEqual(reloaded.accessToken(), "kc-access")
        XCTAssertEqual(reloaded.refreshToken(), "kc-refresh")

        store.clear()
        XCTAssertNil(store.accessToken())
        XCTAssertNil(KeychainTokenStore(service: testService).refreshToken())
    }

    func testKeychainTokenStoreRotation() {
        let store = KeychainTokenStore(service: testService)
        store.save(TokenPair(accessToken: "old-access", refreshToken: "old-refresh"))
        store.save(TokenPair(accessToken: "new-access", refreshToken: "new-refresh"))

        XCTAssertEqual(store.accessToken(), "new-access")
        XCTAssertEqual(store.refreshToken(), "new-refresh")
    }
}
