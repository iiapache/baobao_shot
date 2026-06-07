# Sentry SPM 依赖占位（T7.7）

> 当前使用 **stub 实现**，不引入 `sentry-cocoa`，保证本地与 CI 可无密钥编译。  
> 完整接入步骤见 [infra/observability/sentry/ios-integration.md](../../../../infra/observability/sentry/ios-integration.md)。

## 1. Xcode 添加远程包（BabyCamera Target）

```
https://github.com/getsentry/sentry-cocoa.git
```

版本：`8.36.0` 或更高（最低 iOS 16）。

## 2. 启用 Package.swift 依赖

在 `Packages/BabyCameraDiagnostics/Package.swift` 中取消注释：

```swift
.package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.36.0"),
// target dependencies:
.product(name: "Sentry", package: "sentry-cocoa"),
```

## 3. 替换 Stub

将 `SentryReportingStub.swift` 中的占位逻辑替换为：

```swift
import Sentry

SentrySDK.start { options in
    options.dsn = dsn
    options.environment = configuration.environment
    // ...
}
```

## 4. DSN 配置

- Info.plist：`SentryDSN`（见 `BabyCamera/Resources/Info-Supplement.plist`）
- 密钥：`BabyCamera/Resources/Config/CrashReporting.Secrets.xcconfig`（不入库，见 `.example`）

Vault 路径：`secret/{env}/cn/shared/sentry` → `ios_dsn`。

## 5. 验收

- [ ] Debug 构建启动无 crash
- [ ] Smoke test 错误出现在 Sentry Issues（project: `baobao-ios`）
- [ ] 与 Bugly 双采集并行（见 `BuglyReportingStub.swift`）
