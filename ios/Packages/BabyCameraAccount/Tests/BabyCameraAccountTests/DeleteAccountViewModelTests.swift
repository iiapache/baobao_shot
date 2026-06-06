import BabyCameraNetwork
import XCTest
@testable import BabyCameraAccount

@MainActor
final class DeleteAccountViewModelTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeViewModel(tokenStore: TokenStore = InMemoryTokenStore(
        access: "access",
        refresh: "refresh"
    )) -> DeleteAccountViewModel {
        let service = AuthService(
            configuration: AuthServiceConfiguration(
                region: .cn,
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: tokenStore,
                session: MockURLProtocol.makeSession()
            )
        )
        return DeleteAccountViewModel(authService: service)
    }

    func testConfirmDeletionSuccess() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/account" {
                return MockResponse(statusCode: 200, json: MockServer.deletionSuccessJSON())
            }
            return nil
        }

        let tokenStore = InMemoryTokenStore(access: "access", refresh: "refresh")
        let viewModel = makeViewModel(tokenStore: tokenStore)

        let success = await viewModel.confirmDeletion()

        XCTAssertTrue(success)
        XCTAssertEqual(viewModel.deletionResult?.scheduledAt, "2026-06-13T10:00:00Z")
        XCTAssertNil(tokenStore.refreshToken())
    }
}
