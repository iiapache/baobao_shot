import Foundation

public enum BaiduPanProviderFactory {
    public static func make(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        useLiveOAuthOverride: Bool? = nil,
        tokenStore: (any BaiduPanTokenStoring)? = nil,
        openAPI: (any BaiduPanOpenAPIProviding)? = nil
    ) -> BaiduPanProvider {
        let mode = BaiduPanOAuthConfiguration.resolveMode(
            bundle: bundle,
            forceStub: forceStub,
            useLiveOAuthOverride: useLiveOAuthOverride
        )
        switch mode {
        case .stub:
            return .stub(
                oauth: StubBaiduPanOAuthService(),
                openAPI: openAPI ?? MockBaiduPanOpenAPIClient(),
                tokenStore: tokenStore ?? InMemoryBaiduPanTokenStore()
            )
        case .live:
            return .live(
                oauth: LiveBaiduPanOAuthService(configurationBundle: bundle),
                openAPI: openAPI ?? BaiduPanOpenAPIClient(),
                tokenStore: tokenStore ?? KeychainBaiduPanTokenStore()
            )
        }
    }

    public static func currentMode(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        useLiveOAuthOverride: Bool? = nil
    ) -> BaiduPanOAuthMode {
        BaiduPanOAuthConfiguration.resolveMode(
            bundle: bundle,
            forceStub: forceStub,
            useLiveOAuthOverride: useLiveOAuthOverride
        )
    }
}
