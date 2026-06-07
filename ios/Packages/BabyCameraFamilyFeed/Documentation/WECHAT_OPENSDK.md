# 微信 OpenSDK 真机分享（INT-05 / T5.13）

> 默认 **stub**（单测 / CI / 未链接 SDK）；Staging/Release 在链接 `WechatOpenSDK` 且 `WechatUseOpenSDK=YES` 时走真机 OpenSDK。

## 1. 架构

| 组件 | 职责 |
| --- | --- |
| `WechatShareAdapter` | 文案格式化、缩略图压缩、UA 校验 |
| `WechatOpenSDKBridgeFactory` | `stub` ↔ `live`（`canImport(WechatOpenSDK)` + Info.plist） |
| `WechatOpenSDKBridgeLive` | `WXApi.send` 朋友圈 / 好友 |
| `WechatOpenSDKRegistrar` | 启动注册、`onOpenURL` / Universal Link 回调 |
| `WechatShareAdapterFactory` | 宿主 App 统一构造入口 |

## 2. 配置（xcconfig → Info.plist）

| 键 | xcconfig | 说明 |
| --- | --- | --- |
| `WechatAppID` | `WECHAT_APP_ID` | 开放平台 AppID（URL Scheme 同为 `wx…`） |
| `WechatUniversalLink` | `WECHAT_UNIVERSAL_LINK` | 与开放平台登记一致，须 HTTPS 且路径以 `/` 结尾 |
| `WechatUseOpenSDK` | `WECHAT_USE_OPENSDK` | `YES` / `NO` |

文件：

- 默认：`BabyCamera/Resources/Config/Wechat.xcconfig`
- 密钥：`BabyCamera/Resources/Config/Wechat.Secrets.xcconfig`（复制 `.example`，不入库）

### 环境默认值

| Scheme | `WECHAT_USE_OPENSDK` | Universal Link |
| --- | --- | --- |
| Debug | `NO`（stub） | `https://app.babycamera.cn/wechat/` |
| Staging | `YES` | `https://staging-api-cn.example.com/wechat/` |
| Release | `YES` | `https://app.babycamera.cn/wechat/` |

> **mock-wechat**（`tests/mocks/wechat`、端口 18082）仅用于 **后端** `auth-family-svc` 的 OAuth/token 联调，**不替代** iOS OpenSDK。端侧分享始终调起本机微信 App；AppID 须为开放平台真实/测试号。

## 3. 启用真机 OpenSDK

```bash
# 1. 链接 SPM（BabyCameraFamilyFeed）
./ios/Packages/BabyCameraFamilyFeed/scripts/enable-wechat-opensdk.sh
cd ios && xcodebuild -resolvePackageDependencies -workspace BabyCamera.xcworkspace -scheme BabyCamera-Staging

# 2. 填入测试 AppID（Staging 示例）
cp BabyCamera/Resources/Config/Wechat.Secrets.xcconfig.example \
   BabyCamera/Resources/Config/Wechat.Secrets.xcconfig
# 编辑 Staging.xcconfig：取消 #include "Wechat.Secrets.xcconfig"

# 3. 开放平台配置
# - iOS 应用 Bundle ID：com.babycamera.app
# - Universal Link 与 WECHAT_UNIVERSAL_LINK 一致
# - 关联域名已在 BabyCamera.entitlements（applinks:…）
```

Info.plist 已包含：

- `CFBundleURLSchemes` = `$(WECHAT_APP_ID)`
- `LSApplicationQueriesSchemes`：`weixin` / `weixinULAPI` / `weixinURLParamsAPI`

## 4. 宿主 App 接线

`BabyCameraApp` 启动时调用 `WechatOpenSDKRegistrar.registerIfNeeded()`，并处理：

- `.onOpenURL` → `WechatOpenSDKRegistrar.handleOpenURL`
- `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` → `handleUniversalLink`

分享调用：

```swift
let adapter = WechatShareAdapterFactory.make()
try await adapter.share(WechatShareRequest(asset: prepared, caption: caption, scene: .timeline))
```

## 5. 真机验收步骤

| # | 步骤 | 预期 |
| --- | --- | --- |
| 1 | iPhone 安装微信；Staging 包 `WechatUseOpenSDK=YES` 且已 `enable-wechat-opensdk.sh` | `WechatShareAdapterFactory.currentMode()` 为 `live` |
| 2 | 家庭圈选图 → 分享朋友圈 | 调起微信，缩略图 ≤32KB，文案为 caption |
| 3 | 分享好友 | 标题为第一行，描述为全文 |
| 4 | 未安装微信 | `WechatShareError.wechatNotInstalled` |
| 5 | Debug / `WECHAT_USE_OPENSDK=NO` | stub 模式，不跳微信，单测全绿 |

降级：分享失败时使用 `SystemShareAdapter`（T5.14）。

## 6. 单测

```bash
cd ios/Packages/BabyCameraFamilyFeed
swift test --filter WechatShareAdapterTests
swift test --filter WechatOpenSDKConfigurationTests
```

## 7. 运维

见 `docs/ops/RUNBOOK.md` §5（Universal Link、缩略图、系统分享兜底）。
