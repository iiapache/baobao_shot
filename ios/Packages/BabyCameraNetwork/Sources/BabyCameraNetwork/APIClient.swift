import Foundation

public typealias TokenRefreshHandler = @Sendable () async throws -> TokenPair

public struct APIClientConfiguration: Sendable {
    public let baseURL: URL
    public let tokenStore: TokenStore
    public let requestInterceptors: [RequestInterceptor]
    public let responseInterceptors: [ResponseInterceptor]
    public let refreshHandler: TokenRefreshHandler?
    public let certificatePinning: CertificatePinningConfiguration

    public init(
        baseURL: URL,
        tokenStore: TokenStore,
        requestInterceptors: [RequestInterceptor] = [],
        responseInterceptors: [ResponseInterceptor] = [],
        refreshHandler: TokenRefreshHandler? = nil,
        certificatePinning: CertificatePinningConfiguration = .default
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.requestInterceptors = requestInterceptors
        self.responseInterceptors = responseInterceptors
        self.refreshHandler = refreshHandler
        self.certificatePinning = certificatePinning
    }

    public static func standard(
        region: AppRegion,
        tokenStore: TokenStore,
        regionConfig: RegionConfig,
        loggingInterceptor: LoggingInterceptor? = nil,
        refreshHandler: TokenRefreshHandler? = nil,
        certificatePinning: CertificatePinningConfiguration = .default
    ) -> APIClientConfiguration {
        var responseInterceptors: [ResponseInterceptor] = []
        if let loggingInterceptor {
            responseInterceptors.append(loggingInterceptor)
        }
        return APIClientConfiguration(
            baseURL: region.baseURL,
            tokenStore: tokenStore,
            requestInterceptors: [
                RegionInterceptor(config: regionConfig),
                AuthInterceptor(tokenStore: tokenStore),
            ],
            responseInterceptors: responseInterceptors,
            refreshHandler: refreshHandler,
            certificatePinning: certificatePinning
        )
    }
}

actor RefreshCoordinator {
    private var inFlight: Task<TokenPair, Error>?

    func refresh(using handler: TokenRefreshHandler) async throws -> TokenPair {
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task { try await handler() }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}

public final class APIClient: @unchecked Sendable {
    public let configuration: APIClientConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let refreshCoordinator = RefreshCoordinator()

    public init(configuration: APIClientConfiguration, session: URLSession? = nil) {
        self.configuration = configuration
        self.session = session ?? CertificatePinningSessionFactory.makeSession(
            configuration: configuration.certificatePinning
        )
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func request<T: Decodable & Sendable>(
        _ endpoint: Endpoint,
        responseType: T.Type = T.self
    ) async throws -> T {
        try await performRequest(endpoint, responseType: responseType, didRefresh: false)
    }

    private func performRequest<T: Decodable & Sendable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        didRefresh: Bool
    ) async throws -> T {
        let urlRequest = try buildURLRequest(for: endpoint)
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkTransportError.invalidResponse
        }

        for interceptor in configuration.responseInterceptors {
            try await interceptor.intercept(httpResponse, data: data, request: urlRequest)
        }

        if httpResponse.statusCode == 401,
           endpoint.authRequirement == .required,
           let apiError = parseAPIError(from: data, statusCode: httpResponse.statusCode),
           apiError.isTokenExpired,
           !didRefresh,
           let refreshHandler = configuration.refreshHandler {
            let tokens = try await refreshCoordinator.refresh(using: refreshHandler)
            configuration.tokenStore.save(tokens)
            return try await performRequest(endpoint, responseType: responseType, didRefresh: true)
        }

        let envelope = try decodeEnvelope(T.self, from: data, statusCode: httpResponse.statusCode)
        guard envelope.code == APIErrorCode.ok.rawValue else {
            throw APIError(
                code: APIErrorCode(rawCode: envelope.code),
                rawCode: envelope.code,
                message: envelope.message ?? "unknown error",
                requestId: envelope.requestId,
                httpStatusCode: httpResponse.statusCode
            )
        }
        guard let payload = envelope.data else {
            if T.self == EmptyData.self {
                return EmptyData() as! T
            }
            throw NetworkTransportError.decodingFailed("missing data field")
        }
        return payload
    }

    private func buildURLRequest(for endpoint: Endpoint) async throws -> URLRequest {
        guard var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        ) else {
            throw NetworkTransportError.invalidURL
        }
        components.queryItems = endpoint.queryItems
        guard let url = components.url else {
            throw NetworkTransportError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        endpoint.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        if let body = try endpoint.encodeBody(with: encoder) {
            request.httpBody = body
        }

        var interceptors = configuration.requestInterceptors
        if endpoint.authRequirement == .none {
            interceptors = interceptors.filter { !($0 is AuthInterceptor) }
        }

        for interceptor in interceptors {
            request = try await interceptor.intercept(request)
        }
        return request
    }

    private struct ErrorEnvelope: Decodable {
        let code: String
        let message: String?
        let requestId: String?
    }

    private func decodeEnvelope<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        statusCode: Int
    ) throws -> APIEnvelope<T> {
        do {
            return try decoder.decode(APIEnvelope<T>.self, from: data)
        } catch {
            if let apiError = parseAPIError(from: data, statusCode: statusCode) {
                throw apiError
            }
            throw NetworkTransportError.decodingFailed(error.localizedDescription)
        }
    }

    private func parseAPIError(from data: Data, statusCode: Int) -> APIError? {
        guard let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) else {
            return nil
        }
        let code = APIErrorCode(rawCode: envelope.code)
        guard code != .ok else { return nil }
        return APIError(
            code: code,
            rawCode: envelope.code,
            message: envelope.message ?? "unknown error",
            requestId: envelope.requestId,
            httpStatusCode: statusCode
        )
    }
}
