# Sentry / Bugly 第三方依赖占位（T7.7）

当前工程使用 **stub 实现**（`BabyCameraDiagnostics`），无需添加以下依赖即可编译。

## Sentry（SPM）

```
https://github.com/getsentry/sentry-cocoa.git
```

版本：`from: "8.36.0"`

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
