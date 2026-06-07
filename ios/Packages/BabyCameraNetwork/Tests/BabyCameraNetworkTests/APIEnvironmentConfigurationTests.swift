import Foundation
import XCTest
@testable import BabyCameraNetwork

final class APIEnvironmentConfigurationTests: XCTestCase {
    override func tearDown() {
        APIEnvironmentConfiguration.resetCachedConfiguration()
        super.tearDown()
    }

    func testReadsURLsFromTestingOverride() {
        let configuration = APIEnvironmentConfiguration(
            cnAPIBaseURL: URL(string: "http://localhost:18080")!,
            osAPIBaseURL: URL(string: "http://localhost:18081")!,
            cnWebSocketBaseURL: URL(string: "ws://localhost:18080")!,
            osWebSocketBaseURL: URL(string: "ws://localhost:18081")!
        )

        APIEnvironmentConfiguration.setTestingOverride(configuration)
        defer { APIEnvironmentConfiguration.setTestingOverride(nil) }

        XCTAssertEqual(AppRegion.cn.baseURL.absoluteString, "http://localhost:18080")
        XCTAssertEqual(AppRegion.os.baseURL.absoluteString, "http://localhost:18081")
        XCTAssertEqual(AppRegion.cn.webSocketBaseURL.absoluteString, "ws://localhost:18080")
        XCTAssertEqual(AppRegion.os.webSocketBaseURL.absoluteString, "ws://localhost:18081")
    }

    func testFallsBackToProductionWhenPlistMissing() {
        let configuration = APIEnvironmentConfiguration(infoDictionary: [:])
        XCTAssertEqual(configuration.baseURL(for: .cn), AppRegion.productionBaseURL(for: .cn))
        XCTAssertEqual(configuration.webSocketBaseURL(for: .os), AppRegion.productionWebSocketBaseURL(for: .os))
    }

    func testIgnoresUnexpandedBuildSettingPlaceholders() {
        let configuration = APIEnvironmentConfiguration(infoDictionary: [
            "APIBaseURLCN": "$(API_BASE_URL_CN)",
            "APIBaseURLOS": "https://staging-api-os.example.com",
            "WebSocketBaseURLCN": "$(WS_BASE_URL_CN)",
            "WebSocketBaseURLOS": "wss://staging-ws-os.example.com",
        ])
        XCTAssertEqual(configuration.baseURL(for: .cn), AppRegion.productionBaseURL(for: .cn))
        XCTAssertEqual(configuration.baseURL(for: .os).absoluteString, "https://staging-api-os.example.com")
        XCTAssertEqual(configuration.webSocketBaseURL(for: .cn), AppRegion.productionWebSocketBaseURL(for: .cn))
        XCTAssertEqual(configuration.webSocketBaseURL(for: .os).absoluteString, "wss://staging-ws-os.example.com")
    }
}
