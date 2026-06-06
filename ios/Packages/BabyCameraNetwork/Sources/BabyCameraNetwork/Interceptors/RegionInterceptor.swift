import Foundation

public final class RegionInterceptor: RequestInterceptor, @unchecked Sendable {
    private let config: RegionConfig

    public init(config: RegionConfig) {
        self.config = config
    }

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        request.setValue(config.region.headerValue, forHTTPHeaderField: "X-Region")
        request.setValue(config.appVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue(config.deviceId, forHTTPHeaderField: "X-Device-Id")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
