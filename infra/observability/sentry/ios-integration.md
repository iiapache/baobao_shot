# Sentry iOS SDK 接入

> 与 `ios/BabyCamera` 及 SPM 包结构对齐；Bugly 并行接入见 T7.7。

## 1. 添加依赖

在 Xcode → BabyCamera Target → Package Dependencies：

```
https://github.com/getsentry/sentry-cocoa.git
```

版本：`8.36.0` 或更高（与最低 iOS 16 兼容）。

或在 `Package.swift` / Xcode 项目中添加：

```swift
.package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.36.0")
```

## 2. 初始化

`ios/BabyCamera/App/BabyCameraApp.swift`：

```swift
import Sentry

@main
struct BabyCameraApp: App {
    init() {
        configureSentry()
    }

    private func configureSentry() {
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String,
              !dsn.isEmpty else {
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = Bundle.main.object(forInfoDictionaryKey: "AppEnvironment") as? String ?? "dev"
            options.releaseName = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            options.tracesSampleRate = 0.1
            options.enableAutoSessionTracking = true
            options.attachScreenshot = false  // 隐私：默认关闭
            options.beforeSend = { event in
                // 脱敏：移除 user.email、自定义字段中的 token
                event.user?.email = nil
                return event
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## 3. DSN 配置（不入库）

**Debug**：`ios/BabyCamera/Resources/Config/Debug.xcconfig`（gitignore）：

```
SENTRY_DSN = https://<key>@o<org>.ingest.sentry.io/<ios-project>
APP_ENVIRONMENT = dev
```

**Info.plist** 引用：

```xml
<key>SentryDSN</key>
<string>$(SENTRY_DSN)</string>
<key>AppEnvironment</key>
<string>$(APP_ENVIRONMENT)</string>
```

CI / TestFlight：从 Vault 或 GitLab CI Variables 注入 `SENTRY_DSN`，写入 xcconfig 或 build setting。

Vault 路径：`secret/{env}/cn/shared/sentry` → `ios_dsn`。

## 4. 示例异常（T0.8 验收）

Debug 菜单或 `#if DEBUG` 块：

```swift
#if DEBUG
Button("Sentry Smoke Test") {
    SentrySDK.capture(error: NSError(
        domain: "app.babycamera",
        code: 1001,
        userInfo: [NSLocalizedDescriptionKey: "T0.8 iOS sentry smoke test"]
    ))
}
#endif
```

运行 App → 点击按钮 → Sentry Issues（project: `baobao-ios`）应出现该错误。

## 5. 与后端 trace 关联

若后端返回 `sentry-trace` / W3C `traceparent` header，可在 URLSession 中透传以便 Sentry Performance 关联。当前阶段 OTEL 为主，Sentry 仅错误监控。

## 6. 隐私合规

- 不上传相册、人脸、儿童信息。
- `attachViewHierarchy = false`（默认）。
- App Store 隐私问卷中声明 Sentry 为「诊断」类 SDK。

## 7. 验证清单

- [ ] Debug 构建启动无 crash
- [ ] Smoke test 错误出现在 Sentry Issues
- [ ] Environment 显示 `dev`
- [ ] 未携带 Token / 手机号字段
