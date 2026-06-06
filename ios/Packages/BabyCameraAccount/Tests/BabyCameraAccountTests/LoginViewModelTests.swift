import BabyCameraNetwork
import XCTest
@testable import BabyCameraAccount

@MainActor
final class LoginViewModelTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeViewModel(
        tokenStore: TokenStore = InMemoryTokenStore(),
        appleSignIn: MockAppleSignIn = MockAppleSignIn()
    ) -> (LoginViewModel, AuthService, MockAppleSignIn) {
        let service = AuthService(
            configuration: AuthServiceConfiguration(
                region: .cn,
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: tokenStore,
                session: MockURLProtocol.makeSession()
            )
        )
        let viewModel = LoginViewModel(authService: service, appleSignIn: appleSignIn)
        return (viewModel, service, appleSignIn)
    }

    func testAppleSignInSuccess() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/auth/apple" {
                return MockResponse(statusCode: 200, json: MockServer.loginSuccessJSON())
            }
            return nil
        }

        let (viewModel, _, _) = makeViewModel()
        let session = await viewModel.signInWithApple()

        XCTAssertNotNil(session)
        XCTAssertEqual(session?.userId, "usr_test_001")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAppleSignInFailureSetsError() async {
        let appleSignIn = MockAppleSignIn()
        appleSignIn.shouldThrow = true
        let (viewModel, _, _) = makeViewModel(appleSignIn: appleSignIn)

        let session = await viewModel.signInWithApple()
        XCTAssertNil(session)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testSendVerificationCodeStartsCooldown() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/auth/phone/code" {
                return MockResponse(statusCode: 200, json: MockServer.emptySuccessJSON())
            }
            return nil
        }

        let (viewModel, _, _) = makeViewModel()
        viewModel.phone = "13800138000"

        await viewModel.sendVerificationCode()

        XCTAssertEqual(viewModel.codeCooldownSeconds, 60)
        XCTAssertFalse(viewModel.canSendCode)
    }

    func testPhoneLoginSuccess() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/auth/phone/login" {
                return MockResponse(statusCode: 200, json: MockServer.loginSuccessJSON())
            }
            return nil
        }

        let (viewModel, _, _) = makeViewModel()
        viewModel.phone = "13800138000"
        viewModel.verificationCode = "123456"

        let session = await viewModel.loginWithPhone()
        XCTAssertEqual(session?.userId, "usr_test_001")
    }

    func testPhoneLoginValidation() async {
        let (viewModel, _, _) = makeViewModel()
        viewModel.phone = "138"
        viewModel.verificationCode = "12"

        XCTAssertFalse(viewModel.canSubmitPhoneLogin)
        let session = await viewModel.loginWithPhone()
        XCTAssertNil(session)
    }
}
