# OpenFeature iOS 接入指南

> 端侧默认拉取 `config-svc` REST；可选接入 OpenFeature + Unleash Frontend API。

## 方案 A：config-svc REST（P0 默认）

与 `BabyCameraNetwork` 共用 region 头：

```swift
import Foundation

/// 与 config-svc/internal/feature/hash.go 对齐的 FNV-1a 分桶。
public enum FeatureHash {
    public static func userIDHash(_ userID: String) -> Int {
        guard !userID.isEmpty else { return 0 }
        var hash: UInt32 = 2166136261
        for byte in userID.utf8 {
            hash ^= UInt32(byte)
            hash &*= 16777619
        }
        return Int(hash % 100)
    }
}

public struct FeatureFlagsClient {
    private let baseURL: URL
    private let regionConfig: RegionConfig

    public init(regionConfig: RegionConfig) {
        self.regionConfig = regionConfig
        self.baseURL = regionConfig.region.baseURL
    }

    public func fetchFeatures(userID: String?, token: String?) async throws -> [String: FeatureFlag] {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/config/features"))
        request.setValue(regionConfig.region.headerValue, forHTTPHeaderField: "X-Region")
        request.setValue(regionConfig.appVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue(regionConfig.deviceId, forHTTPHeaderField: "X-Device-Id")
        if let userID {
            request.setValue("\(FeatureHash.userIDHash(userID))", forHTTPHeaderField: "X-User-Id-Hash")
        }
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(APIResponse<FeatureFlagsPayload>.self, from: data)
        return decoded.data.features
    }
}

public struct FeatureFlag: Decodable {
    public let enabled: Bool
    public let variant: String?
}

public struct FeatureFlagsPayload: Decodable {
    public let version: String
    public let ttlSeconds: Int
    public let features: [String: FeatureFlag]
}
```

**缓存建议**：按 `ttlSeconds`（默认 300s）本地缓存；`version` 变更时强制刷新。

## 方案 B：OpenFeature Swift SDK（可选）

```swift
// Package.swift 添加（版本以官方为准）:
// .package(url: "https://github.com/open-feature/swift-sdk", from: "0.3.0"),

import OpenFeature

func configureUnleashFrontend() {
    // Unleash Frontend API: http://localhost:4242/api/frontend
    // Provider 注册见 OpenFeature Swift 文档
}

func isStorybookEnabled(userID: String, region: AppRegion) -> Bool {
    let client = OpenFeatureAPI.shared.getClient()
    let ctx = EvaluationContext(
        targetingKey: userID,
        attributes: [
            "region": .string(region.rawValue),
            "userIdHash": .int(FeatureHash.userIDHash(userID))
        ]
    )
    return (try? client.getBooleanValue(key: "ai.storybook", defaultValue: false, context: ctx)) ?? false
}
```

## 分流一致性检查

```swift
// 单元测试：与 Go 服务同一 userId 应得到相同 userIdHash
XCTAssertEqual(FeatureHash.userIDHash("usr_test_001"), 18) // 与 golden_hashes.json 对齐
```

在 CI 中维护 golden 向量文件（`infra/feature-flags/golden_hashes.json`）跨 Go / iOS 校验。

## Unleash Frontend（本地）

```bash
cd infra/feature-flags && docker compose up -d
# Frontend API: http://localhost:4242/api/frontend
# Token: development.unleash-insecure-frontend-token
```

## 参考

- [OpenFeature Swift SDK](https://openfeature.dev/docs/reference/technologies/client/swift)
- [Unleash Frontend API](https://docs.getunleash.io/reference/front-end-api)
- `ios/Packages/BabyCameraNetwork/Sources/BabyCameraNetwork/RegionConfig.swift`
