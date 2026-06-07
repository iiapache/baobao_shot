# 激励广告 Staging 联调指南（INT-04）

> **范围**：穿山甲 / 优量汇 / AdMob 激励视频 → `POST /v1/credits/ad-reward` → 积分入账；联盟 SSV → credit-sub-ad-svc  
> **关联**：[`tests/staging/README.md`](../../tests/staging/README.md)、[`tests/e2e/README-p4-credit.md`](../../tests/e2e/README-p4-credit.md)

---

## 1. 模式切换

| 模式 | 适用场景 | SDK 实现 | 广告位 ID | 入账通道 |
| --- | --- | --- | --- | --- |
| **stub** | Debug 默认、模拟器、`-UITesting` | `StubAdSDKClient` | `*_stub` | 端侧上报 → Mock API / credit-sub-ad-svc |
| **liveSDK** | Staging / Release、真机 | `StagingBridgeAdSDKClient`（未链 SDK）或真实联盟 SDK | xcconfig 测试位 / 生产位 | 端侧上报 + 联盟 SSV（mock-ad 或真实） |

### 1.1 编译条件（xcconfig → Info.plist）

| Build Configuration | `ADS_USE_LIVE_SDK` | 行为 |
| --- | --- | --- |
| Debug | `NO` | stub 广告 |
| Staging | `YES` | live SDK（默认 Staging Bridge） |
| Release | `YES` | live SDK |

Debug 真机走 Staging 激励联调：将 `Debug.xcconfig` 中 `ADS_USE_LIVE_SDK = YES` 后 **Clean Build**。

验证注入：

```bash
cd ios
xcodebuild -project BabyCamera.xcodeproj -scheme BabyCamera -showBuildSettings | rg 'ADS_USE_LIVE_SDK'
xcodebuild -project BabyCamera.xcodeproj -scheme BabyCamera-Staging -configuration Staging -showBuildSettings | rg 'ADS_USE_LIVE_SDK'
```

### 1.2 Feature Flag（运行时覆盖）

config-svc 键 **`ads.live_sdk`**（`enabled: false` 强制 stub，`true` 强制 live SDK）。

端侧工厂：`AdSDKClientFactory.makeClients(featureFlagEnabled: …)` / `AdManagerFactory.make(featureFlagEnabled: …)`。

### 1.3 UI 测试

启动参数含 `-UITesting` 时，`ProfileIntegrationContextFactory` 强制 stub，与 `MockURLProtocol` 配套。

### 1.4 链接真实联盟 SDK（可选）

默认 Staging 使用 **Staging Bridge**（无第三方依赖，CI 可编译）。链接穿山甲 / 优量汇 / AdMob 后：

```bash
cd ios/ThirdParty
./enable-ad-sdks.sh   # 设置 BABYCAMERA_AD_SDK_LIVE + SPM/Pods
```

在 `LiveAdSDKClients.swift` 中补充 `PangleAdSDKClient` / `GDTAdSDKClient` / `AdMobAdSDKClient` 实现。

---

## 2. 前置条件

### 2.1 端侧

1. Scheme：`BabyCamera-Staging`（Staging configuration）。
2. 测试账号：[`tests/accounts/test-accounts.yaml`](../../tests/accounts/test-accounts.yaml) 中 `status: active`。
3. 广告位 ID：见 `ios/BabyCamera/Resources/Config/Ads.xcconfig`（穿山甲 / AdMob 官方测试位）。

### 2.2 后端

| 环境 | API | 广告验签 / SSV |
| --- | --- | --- |
| 本地 Mock | `http://localhost:18080` | WireMock `43-credits-ad-pangle-callback.json` |
| Staging | Staging 网关 | credit-sub-ad-svc + `mock-ad`（`:18083`） |

Staging credit-sub-ad-svc 密钥（配合 mock-ad）：

- `PANGLE_SECURITY_KEY=staging-mock-pangle-secret`
- `GDT_SECRET_KEY=staging-mock-gdt-secret`

见 [`infra/staging/values/credit-sub-ad-svc.yaml`](../../infra/staging/values/credit-sub-ad-svc.yaml)。

---

## 3. 验证步骤

### 3.1 Debug + stub（模拟器 / 本地 Mock）

1. Scheme：`BabyCamera`（Debug），确认 `ADS_USE_LIVE_SDK = NO`。
2. 启动 Mock API：`cd tests/mocks/api && python3 mock_server.py`
3. App 登录测试账号 → **我的** → **积分余额** → **看广告得积分**。
4. 观看完成（stub 自动成功）→ 余额 +5。
5. 确认请求：
   - `POST /v1/credits/ad-reward`
   - Body：`network=pangle`、`placementId=pangle_rewarded_stub`、`transId=…`

### 3.2 Staging + liveSDK（真机 / TestFlight）

1. Scheme：`BabyCamera-Staging`，`ADS_USE_LIVE_SDK = YES`。
2. 真机安装，登录测试账号。
3. **我的** → **积分余额** → **看广告得积分**。
4. Staging Bridge 或真实 SDK 展示激励视频 → 完整观看。
5. 确认：
   - 端侧 `POST /v1/credits/ad-reward`（`placementId` 为测试位，如 `945494739`）
   - `transId` 格式 `pangle-staging-reward-<uuid>`（Bridge）或联盟真实流水号
   - 余额增加，流水出现 `ad_reward` 记录
6. 杀进程重启，余额保持一致。

### 3.3 联盟 SSV 回调（服务端通道）

端侧上报与联盟 SSV 为**双通道**；Staging 验 SSV 可走 mock-ad：

```bash
# 本地 mock-ad（可选）
cd tests/mocks && docker compose up -d mock-ad

# e2e 脚本（含 client report + pangle callback）
tests/e2e/p4-e2e.sh
```

手动模拟穿山甲 SSV（需与 staging 密钥一致）：

```bash
SECRET="staging-mock-pangle-secret"
TRANS_ID="mock-trans-staging-001"
USER_ID="usr_smoke_001"
SIGN=$(printf '%s' "${TRANS_ID}:${USER_ID}" | openssl dgst -sha256 -hmac "${SECRET}" | awk '{print $2}')

curl -s -X POST "https://<staging-gateway>/v1/credits/ad-reward/pangle/callback" \
  -H 'Content-Type: application/json' \
  -d "{\"user_id\":\"${USER_ID}\",\"trans_id\":\"${TRANS_ID}\",\"sign\":\"${SIGN}\",\"extra\":\"{}\"}"
```

重复 `trans_id` 应返回 `duplicate: true` 且不重复入账。

---

## 4. 常见问题

| 现象 | 排查 |
| --- | --- |
| 按钮无响应 | 是否登录；Token 是否有效；`AdManager.isShowingAd` 是否卡住 |
| 观看完成未入账 | credit-sub-ad-svc 日志；`CREDIT_AD_*` 错误码；单日 ≤5 次限制 |
| Staging 仍走 stub | 检查 `ADS_USE_LIVE_SDK`、Feature Flag `ads.live_sdk`、Clean Build |
| placementId 仍为 `*_stub` | `ADS_USE_LIVE_SDK` 未生效或 Feature Flag 强制 stub |
| 模拟器无法测真实 SDK | 正常；Debug 默认 stub，或 Staging Bridge |

---

## 5. 代码入口

| 组件 | 路径 |
| --- | --- |
| 模式解析 | `BabyCameraCredit/Services/Ads/AdConfiguration.swift` |
| SDK 工厂 | `BabyCameraCredit/Services/Ads/AdSDKClientFactory.swift` |
| Staging Bridge | `BabyCameraCredit/Services/Ads/StagingBridgeAdSDKClients.swift` |
| 真实 SDK 适配 | `BabyCameraCredit/Services/Ads/LiveAdSDKClients.swift` |
| AdManager 工厂 | `BabyCameraCredit/Services/Ads/AdManagerFactory.swift` |
| 激励入口 UI | `BabyCameraCredit/Views/RewardedAdEntry.swift` |
| App 装配 | `BabyCamera/App/ProfileIntegrationContextFactory.swift` |
| 广告位配置 | `BabyCamera/Resources/Config/Ads.xcconfig` |
