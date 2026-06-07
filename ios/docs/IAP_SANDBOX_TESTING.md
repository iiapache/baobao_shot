# IAP 沙盒联调指南（INT-03）

> **范围**：StoreKit 2 沙盒购买 → `POST /v1/credits/iap-verify` / `POST /v1/subscriptions/iap-verify` → 积分/订阅到账  
> **关联**：[`IAP_PRODUCTS.md`](../../compliance/app-store/IAP_PRODUCTS.md)、[`ios/README.md`](../README.md)

---

## 1. 模式切换

| 模式 | 适用场景 | 购买来源 | 校验 JWS |
| --- | --- | --- | --- |
| **stub** | Debug 默认、模拟器、`-UITesting` | `StubIAPStoreClient` 生成 `mock:tx:productId` | credit-sub-ad-svc 本地 mock 解析 |
| **storeKit** | Staging / Release、真机沙盒 | Apple StoreKit 2 | 真实 JWS（staging 后端可走 mock-iap 或 Apple 沙盒） |

### 1.1 编译条件（xcconfig → Info.plist）

| Build Configuration | `IAP_USE_STOREKIT` | 行为 |
| --- | --- | --- |
| Debug | `NO` | stub IAP |
| Staging | `YES` | StoreKit 2 |
| Release | `YES` | StoreKit 2 |

修改 `ios/BabyCamera/Resources/Config/Debug.xcconfig` 中 `IAP_USE_STOREKIT = YES` 并 **Clean Build**，可在 Debug 真机上走 StoreKit 沙盒。

验证注入：

```bash
cd ios
xcodebuild -project BabyCamera.xcodeproj -scheme BabyCamera -showBuildSettings | rg 'IAP_USE_STOREKIT'
xcodebuild -project BabyCamera.xcodeproj -scheme BabyCamera-Staging -configuration Staging -showBuildSettings | rg 'IAP_USE_STOREKIT'
```

### 1.2 Feature Flag（运行时覆盖）

config-svc 键 **`iap.storekit2`**（`enabled: false` 强制 stub，`true` 强制 StoreKit）。

端侧工厂：`IAPStoreClientFactory.make(featureFlagEnabled: …)`。App 层可在拉取 `/v1/config/features` 后将 flag 传入 `ProfileIntegrationContextFactory`（当前默认仅编译条件 + UITest 强制 stub）。

### 1.3 UI 测试

启动参数含 `-UITesting` 时，`ProfileIntegrationContextFactory` 强制 `StubIAPStoreClient`，与 `MockURLProtocol` 配套。

---

## 2. 前置条件

### 2.1 Apple 侧

1. App Store Connect 创建 Product ID（见 `IAP_PRODUCTS.md`）：
   - 积分：`credit_pack_60` / `credit_pack_330` / `credit_pack_800` / `credit_pack_2500`
   - 订阅：`com.baobao.sub.monthly` 等
2. 创建 **Sandbox Tester**（Settings → App Store → Sandbox Account）。
3. 真机登录沙盒账号（**不要**用生产 Apple ID 测 IAP）。
4. Xcode：**Signing & Capabilities** 勾选 **In-App Purchase**。

### 2.2 后端

| 环境 | API | IAP 校验 |
| --- | --- | --- |
| 本地 Mock | `http://localhost:18080` | mock JWS + WireMock 映射 |
| Staging | `BabyCamera-Staging` Scheme | credit-sub-ad-svc + `mock-iap` 或 Apple 沙盒 |

本地 Mock：

```bash
cd tests/mocks/api && python3 mock_server.py
# 或 docker compose up mock-api
```

Staging 见 [tests/staging/README.md](../../tests/staging/README.md)。

### 2.3 测试账号

使用 [tests/accounts/test-accounts.yaml](../../tests/accounts/test-accounts.yaml) 中 `status: active` 账号登录 App，确保 Bearer Token 有效。

---

## 3. 沙盒验证步骤

### 3.1 Debug + stub（模拟器 / 本地 Mock）

1. Scheme：`BabyCamera`（Debug），确认 `IAP_USE_STOREKIT = NO`。
2. 启动 Mock API（`:18080`）。
3. App 登录测试账号 → **我的** → **积分余额** → **充值**。
4. 选择档位购买 → 应弹出成功提示，余额增加。
5. 抓包或 Mock 日志确认：
   - `POST /v1/credits/iap-verify`
   - Body 含 `transactionId`、`signedTransaction`（`mock:…`）、`productId`

订阅：**我的** → **会员订阅** → 点击方案 → `POST /v1/subscriptions/iap-verify`。

### 3.2 Staging + StoreKit 沙盒（真机）

1. Scheme：`BabyCamera-Staging`（Staging），`IAP_USE_STOREKIT = YES`。
2. 真机安装，Settings 登录 **Sandbox Tester**。
3. 登录 App 测试账号，重复 3.1 充值/订阅流程。
4. StoreKit 弹出 Apple 购买 sheet（显示 `[Environment: Sandbox]`）。
5. 购买成功后：
   - 积分：`IAPService` → `/v1/credits/iap-verify` → `finish(transaction)`
   - 订阅：`SubscriptionStore` → `/v1/subscriptions/iap-verify` → 会员状态刷新
6. 杀进程重启 App，确认 `Transaction.updates` / 待上送队列无遗漏（网络中断场景可断网购买后恢复网络再开 App）。

### 3.3 幂等

同一 `transactionId` 重复上送应返回 `duplicate: true`，客户端仍 `finish(transaction)`。可用 e2e 脚本：

```bash
tests/e2e/p4-e2e.sh
```

---

## 4. 常见问题

| 现象 | 排查 |
| --- | --- |
| 商品列表为空 | ASC Product ID 是否与 `CreditIAPProductID` / `SubscriptionProductID` 一致；沙盒协议是否签署 |
| 购买成功但未到账 | 查 credit-sub-ad-svc 日志；JWS 校验失败率；Token 是否过期 |
| Debug 仍走 StoreKit | 检查 `IAP_USE_STOREKIT` 与 Clean Build |
| 模拟器无法 StoreKit | 正常；Debug 默认 stub，或改用 StoreKit Testing in Xcode |

---

## 5. 代码入口

| 组件 | 路径 |
| --- | --- |
| StoreKit 客户端 | `BabyCameraCredit/Services/StoreKitPurchaseClient.swift` |
| Stub 客户端 | `BabyCameraCredit/Services/StubIAPStoreClient.swift` |
| 工厂 / 切换 | `BabyCameraCredit/Services/IAPStoreClientFactory.swift` |
| 积分 IAP | `BabyCameraCredit/Services/IAPService.swift` |
| 订阅 IAP | `BabyCameraCredit/Services/SubscriptionStore.swift` |
| App 装配 | `BabyCamera/App/ProfileIntegrationContextFactory.swift` |
