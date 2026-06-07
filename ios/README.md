# iOS 端工程

宝宝成长相机 iOS 客户端（iOS 16+，Swift 5.10+）。工程结构与 [design-ios.md §3](../docs/design-ios.md#3-工程结构) 对齐。

## 前置要求

- macOS 14+
- **完整 Xcode 16+**（含 iOS 18 SDK；**不能**仅安装 Command Line Tools）
- Command Line Tools（通常随 Xcode 一并提供）

### ENV-01：安装与验证 Xcode

| 步骤 | 操作 |
| --- | --- |
| 1. 安装 | Mac App Store 或 [developer.apple.com/xcode](https://developer.apple.com/xcode/) 安装 **Xcode 16.x** |
| 2. 切换工具链 | `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| 3. 许可与组件 | `sudo xcodebuild -license accept`，首次 `open -a Xcode` 等待附加组件安装完成 |
| 4. 环境检测 | 仓库根目录执行 `./ios/scripts/verify-xcode-env.sh` |
| 5. 一键构建 | `./ios/scripts/build-babycamera.sh` |

**检测脚本**（`ios/scripts/verify-xcode-env.sh`）会检查：

- `/Applications/Xcode.app` 是否存在
- `xcode-select` 是否指向 Xcode（而非 `/Library/Developer/CommandLineTools`）
- `xcodebuild` 版本 ≥ 16、iOS SDK 是否可用
- `BabyCamera.xcworkspace` / `BabyCamera` Scheme 是否存在

未安装完整 Xcode 时脚本会以非零退出码结束，并打印安装指引。JSON 输出供 CI 使用：

```bash
./ios/scripts/verify-xcode-env.sh --json
```

**构建脚本**（`ios/scripts/build-babycamera.sh`）在通过环境检测后执行：

```bash
xcodebuild -workspace BabyCamera.xcworkspace -scheme BabyCamera build
```

常用变体：

```bash
# 默认：generic/platform=iOS（无需指定模拟器）
./ios/scripts/build-babycamera.sh

# 指定模拟器
./ios/scripts/build-babycamera.sh --simulator "iPhone 16"

# Staging Scheme
./ios/scripts/build-babycamera.sh --scheme BabyCamera-Staging
```

验收标准（ENV-01）：`./ios/scripts/build-babycamera.sh` 退出码为 0。

## 目录结构

```text
ios/
├── BabyCamera.xcodeproj          # Xcode 工程
├── BabyCamera.xcworkspace        # Workspace（含工程 + 根 Package.swift）
├── Package.swift                 # Monorepo SPM 聚合 manifest
├── Package.resolved              # SPM lockfile（首次 build 后生成）
├── BabyCamera/                   # 源码目录（与 design-ios §3.1 一致）
│   ├── App/                      # @main 入口
│   ├── Features/                 # 业务 Feature（Account / Camera / …）
│   ├── Core/                     # 跨 Feature 复用
│   ├── Data/                     # 持久化与仓储
│   ├── Network/                  # REST / WebSocket
│   ├── UIKitBridge/              # UIKit 桥接
│   ├── Widgets/                  # 小组件 Target 占位
│   └── Resources/                # Assets / 本地化 / 字体
└── Packages/                     # 本地 SPM 模块
    ├── DesignSystem/             # Core/DesignSystem 占位
    ├── Database/                 # Data/Database 占位
    ├── BabyCameraNetwork/        # Network 占位
    ├── UIKitBridge/
    └── Widgets/
```

## 打开工程

```bash
open BabyCamera.xcworkspace
```

或使用 Xcode 直接打开 `BabyCamera.xcodeproj`。

## 命令行构建

推荐先运行 [ENV-01 验证脚本](#env-01安装与验证-xcode)，再使用一键构建：

```bash
./ios/scripts/verify-xcode-env.sh
./ios/scripts/build-babycamera.sh
```

手动 `xcodebuild`（在 `ios/` 目录）：

```bash
# 查看构建设置（验收项）
xcodebuild -workspace BabyCamera.xcworkspace -scheme BabyCamera -showBuildSettings

# 模拟器构建
xcodebuild \
  -workspace BabyCamera.xcworkspace \
  -scheme BabyCamera \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# 通用 iOS 设备（无需指定模拟器）
xcodebuild \
  -workspace BabyCamera.xcworkspace \
  -scheme BabyCamera \
  -destination 'generic/platform=iOS' \
  build
```

## SPM 模块

| 模块 | 路径 | 说明 |
| --- | --- | --- |
| DesignSystem | `Packages/DesignSystem` | 颜色 / 字体 / 组件（T0.14） |
| Database | `Packages/Database` | GRDB + Migration（T0.16） |
| BabyCameraNetwork | `Packages/BabyCameraNetwork` | URLSession 网络层（T0.15） |
| UIKitBridge | `Packages/UIKitBridge` | 相机 / 编辑器 UIKit 桥接 |
| Widgets | `Packages/Widgets` | WidgetKit 小组件 |

根目录 `Package.swift` 提供 monorepo 视角的聚合引用，便于 CI 与 IDE 统一解析。

## 配置

| 项 | 值 |
| --- | --- |
| 最低系统 | iOS 16.0 |
| Swift | 5.10+（Strict Concurrency） |
| Bundle ID | `com.babycamera.app` |
| 显示名称 | 宝宝成长相机 |

### API 环境切换（ENV-04）

端侧 API / WebSocket 基址由 **Build Configuration → xcconfig → Info.plist** 注入，`AppRegion.baseURL` 运行时读取，无需改代码。

| Build Configuration | Xcode Scheme | CN REST | OS REST | CN WebSocket | OS WebSocket |
| --- | --- | --- | --- | --- | --- |
| **Debug** | `BabyCamera` | `http://localhost:18080` | 同左 | `ws://localhost:18080` | 同左 |
| **Staging** | `BabyCamera-Staging` | `https://staging-api-cn.example.com` | `https://staging-api-os.example.com` | `wss://staging-ws-cn.example.com` | `wss://staging-ws-os.example.com` |
| **Release** | Archive / TestFlight 生产包 | `https://api-cn.babygrowth.app` | `https://api-os.babygrowth.app` | `wss://ws-cn.babygrowth.app` | `wss://ws-os.babygrowth.app` |

配置文件位于 `BabyCamera/Resources/Config/`：

| 文件 | 用途 |
| --- | --- |
| `Debug.xcconfig` | 本地 Mock（需先启动 `tests/mocks/api`） |
| `Staging.xcconfig` | Staging 集群联调 / 内测 |
| `Release.xcconfig` | 生产域名 |
| `APIEndpoints.xcconfig` | 生产默认 URL（Release 引用） |

**切换方式：**

1. **本地 Mock**：Scheme 选 `BabyCamera`（Debug），启动 Mock API：
   ```bash
   cd tests/mocks/api && python3 mock_server.py
   # 或：cd tests/mocks && docker compose up -d mock-api
   ```
2. **Staging 联调**：Scheme 选 `BabyCamera-Staging`（Staging configuration），需 VPN / 内网可达 Staging 网关（见 [tests/staging/README.md](../tests/staging/README.md)）。
3. **自定义 URL**：编辑对应 `.xcconfig` 中的 `API_BASE_URL_*` / `WS_BASE_URL_*`，Clean Build 后重装。

Debug 构建会开启 `NSAllowsLocalNetworking`，允许访问 `localhost` HTTP。

### IAP 模式（INT-03）

| Build Configuration | `IAP_USE_STOREKIT` | 购买实现 |
| --- | --- | --- |
| Debug | `NO`（默认 stub） | `StubIAPStoreClient` → mock JWS → 本地 Mock API |
| Staging / Release | `YES` | StoreKit 2 沙盒/生产 → 真实 JWS |

沙盒联调步骤见 [docs/IAP_SANDBOX_TESTING.md](./docs/IAP_SANDBOX_TESTING.md)。Debug 真机 StoreKit 联调：将 `Debug.xcconfig` 中 `IAP_USE_STOREKIT` 改为 `YES` 后 Clean Build。

### 微信分享 OpenSDK（INT-05）

| Build Configuration | `WECHAT_USE_OPENSDK` | 分享实现 |
| --- | --- | --- |
| Debug | `NO`（默认 stub） | `StubWechatOpenSDKBridge`，单测 / 模拟器不跳微信 |
| Staging / Release | `YES` | 链接 `WechatOpenSDK` 后 `WechatOpenSDKBridgeLive` 真机调起微信 |

真机验收步骤见 [Packages/BabyCameraFamilyFeed/Documentation/WECHAT_OPENSDK.md](./Packages/BabyCameraFamilyFeed/Documentation/WECHAT_OPENSDK.md)。启用 SDK：`./Packages/BabyCameraFamilyFeed/scripts/enable-wechat-opensdk.sh`；测试 AppID 写入 `Wechat.Secrets.xcconfig`（复制 `.example`）。

> `mock-wechat`（后端 OAuth）与 iOS OpenSDK 无关；端侧 AppID 须来自微信开放平台。

### Apple 登录真机（INT-02）

| 组件 | 说明 |
| --- | --- |
| 端侧 | `LoginView` → `AppleSignInService` → `AuthService.loginWithApple` → `POST /v1/auth/apple` |
| Capability | `BabyCamera.entitlements` 含 Sign in with Apple；ASC App ID 须同步启用 |
| Staging 后端 | `APPLE_AUTH_MOCK=false` + `APPLE_BUNDLE_ID=com.babycamera.app` 启用 JWKS 校验 |

**真机步骤：** Scheme `BabyCamera-Staging` → 真机 Run → 登录页「通过 Apple 登录」→ 沙盒 Apple ID 授权。ASC 配置与后端切换见 [services/auth-family-svc/README.md](../services/auth-family-svc/README.md) §Apple 登录。

### 激励广告模式（INT-04）

| Build Configuration | `ADS_USE_LIVE_SDK` | 广告实现 |
| --- | --- | --- |
| Debug | `NO`（默认 stub） | `StubAdSDKClient` → 本地 Mock API |
| Staging / Release | `YES` | Staging Bridge 或真实联盟 SDK → credit-sub-ad-svc |

Staging 联调步骤见 [docs/AD_STAGING_TESTING.md](./docs/AD_STAGING_TESTING.md)。Debug 真机激励联调：将 `Debug.xcconfig` 中 `ADS_USE_LIVE_SDK` 改为 `YES` 后 Clean Build。

### 百度网盘备份 OAuth（OPT-03）

| Build Configuration | `BAIDU_PAN_USE_LIVE_OAUTH` | OAuth 实现 |
| --- | --- | --- |
| Debug | `NO`（默认 stub） | `StubBaiduPanOAuthService`，设置页可秒绑 Mock API |
| Staging / Release | `YES` | `ASWebAuthenticationSession` + 百度 token 换票 |

真机验收步骤见 [docs/BAIDU_PAN_OAUTH_STAGING.md](./docs/BAIDU_PAN_OAUTH_STAGING.md)。测试凭据写入 `BaiduPan.Secrets.xcconfig`（复制 `.example`）。

**UI 测试说明：** 带 `-UITesting` 且非 `-P2E2E` / `-P6E2E` 时，`UITestBootstrap` 仍通过 `MockURLProtocol` 拦截请求，不受上述 baseURL 影响；IAP / 广告均强制 stub。

验证注入是否生效：

```bash
cd ios
xcodebuild -project BabyCamera.xcodeproj -scheme BabyCamera -showBuildSettings | rg 'API_BASE_URL_CN'
xcodebuild -project BabyCamera.xcodeproj -scheme BabyCamera-Staging -configuration Staging -showBuildSettings | rg 'API_BASE_URL_CN'
```

## Fastlane（ENV-02）

TestFlight 构建与签名见 [fastlane/README.md](./fastlane/README.md) 与 [TESTFLIGHT_BUILD_CHECKLIST.md](../docs/qa/TESTFLIGHT_BUILD_CHECKLIST.md)。

```bash
cd ios
bundle config set --local path 'vendor/bundle'   # 首次
bundle install
./scripts/verify-signing.sh      # 签名前置检测
bundle exec fastlane build_only  # 仅产出 IPA（需 Apple 证书）
bundle exec fastlane beta        # IPA + 上传 TestFlight
```

默认内测包使用 Scheme **`BabyCamera-Staging`**（Staging API）。
