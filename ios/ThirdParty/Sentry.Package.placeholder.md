# Sentry / Bugly 第三方依赖（T7.7 / UX-05）

`BabyCameraDiagnostics` 已实现 **adapter 层**（Live + Noop Stub）。默认 CI/本地无 SDK 仍可编译；启用真实 SDK 见下文。

## Sentry（SPM）

```
https://github.com/getsentry/sentry-cocoa.git
```

版本：`from: "8.36.0"`

启用 Sentry SPM（Staging/Release 构建）：

```bash
ios/Packages/BabyCameraDiagnostics/scripts/enable-crash-sdks.sh
# 然后在 Xcode 中 File → Packages → Resolve Package Versions
```

接入步骤见：

- `Packages/BabyCameraDiagnostics/Documentation/SENTRY_SPM.md`
- `infra/observability/sentry/ios-integration.md`

## Bugly（CocoaPods / 手动 Framework）

腾讯 Bugly iOS SDK 暂无官方 SPM。推荐：

1. CocoaPods：`pod 'Bugly'`
2. 或手动拖入 `Bugly.framework` + 符号表上传脚本

AppID 配置：`BabyCamera/Resources/Info-Supplement.plist` → `BuglyAppID`

## Info.plist 键

| Key | xcconfig 变量 | 说明 |
| --- | --- | --- |
| `SentryDSN` | `SENTRY_DSN` | Sentry 项目 DSN |
| `BuglyAppID` | `BUGLY_APP_ID` | Bugly 产品 AppID |
| `AppEnvironment` | `APP_ENVIRONMENT` | dev / staging / prod |
| `CrashReportingEnabled` | `CRASH_REPORTING_ENABLED` | YES 时启动双采集 |

默认配置：`BabyCamera/Resources/Config/CrashReporting.xcconfig`（`CRASH_REPORTING_ENABLED = NO`）
