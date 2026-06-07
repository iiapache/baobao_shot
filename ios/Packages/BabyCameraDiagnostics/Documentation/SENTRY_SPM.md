# Sentry SPM 依赖（T7.7 / UX-05）

> Adapter 已实现：`SentryReporting` → `SentryReportingLive`（`canImport(Sentry)`）/ `SentryNoopBackend`（CI、Debug）。  
> 默认不链接 `sentry-cocoa`；设置 `BABYCAMERA_CRASH_SDKS=1` 后解析 SPM 即可启用 Live。  
> 完整步骤见 [infra/observability/sentry/ios-integration.md](../../../../infra/observability/sentry/ios-integration.md)。

## 1. Xcode 添加远程包（BabyCamera Target）

```
https://github.com/getsentry/sentry-cocoa.git
```

版本：`8.36.0` 或更高（最低 iOS 16）。

## 2. 启用 Package.swift 依赖

```bash
./scripts/enable-crash-sdks.sh
```

脚本会取消 `Package.swift` 内 `SENTRY_SPM_*` 注释块，链接 `sentry-cocoa`。

## 3. Live 实现

逻辑位于 `SentryReportingLive.swift`（`#if canImport(Sentry)`），由 `SentryReporting` 门面在 Staging/Release 非 Debug 构建时自动选用。

## 4. DSN 配置

- Info.plist：`SentryDSN`（见 `BabyCamera/Resources/Info-Supplement.plist`）
- 密钥：`BabyCamera/Resources/Config/CrashReporting.Secrets.xcconfig`（不入库，见 `.example`）

Vault 路径：`secret/{env}/cn/shared/sentry` → `ios_dsn`。

## 5. 验收

- [ ] Debug 构建启动无 crash
- [ ] Smoke test 错误出现在 Sentry Issues（project: `baobao-ios`）
- [ ] 与 Bugly 双采集并行（见 `BuglyReportingStub.swift`）
