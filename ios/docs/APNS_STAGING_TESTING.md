# APNs Staging 真机联调指南（INT-08）

> **范围**：APNs Token 注册 → notification-svc 推送 → AI 完成静默下载  
> **关联**：[`infra/staging/README.md`](../../infra/staging/README.md) §4.4、[`services/notification-svc/README.md`](../../services/notification-svc/README.md)

---

## 1. 模式切换

| 层级 | Mock（默认） | Live（真机） |
| --- | --- | --- |
| notification-svc | `APNS_MOCK=true` | `APNS_MOCK=false` + Vault `.p8` 密钥 |
| iOS 端 | 仍走真实 APNs Token 注册 API | 同左；需 Push Capability + `aps-environment` |

### 1.1 后端环境变量

| 变量 | Staging 默认 | 真 APNs |
| --- | --- | --- |
| `APNS_MOCK` | `true` | `false` |
| `APNS_SANDBOX` | `true` | Debug/Staging 包 `true`；生产包 `false` |
| `APNS_TOPIC` | `com.babycamera.app` | 与 Bundle ID 一致 |
| `APNS_KEY_ID` / `APNS_TEAM_ID` / `APNS_PRIVATE_KEY_PEM` | 空 | Vault `notification/apns` |

### 1.2 端侧

- Scheme：`BabyCamera-Staging`
- 登录成功后 `NotificationBootstrap` 调用 `POST /v1/notifications/devices`
- AI Tab bootstrap 后，`NotificationIntegrationBridge` 将静默 `AI_DONE` 推送到 `AITaskCoordinator.handlePushNotification`

---

## 2. 前置条件

1. Apple Developer：App ID 开启 Push Notifications；Provisioning Profile 含 push entitlement。
2. `BabyCamera.entitlements` 含 `aps-environment`（Staging 为 `development`）。
3. Staging 网关可达；notification-svc 已部署（`deploy-staging.sh` 含 `notification-svc`）。
4. 真机允许通知权限。

---

## 3. 验证步骤

### 3.1 Token 注册

1. 真机安装 `BabyCamera-Staging`，登录测试账号。
2. 允许通知；Xcode 控制台应出现 APNs device token 十六进制串。
3. 查后端：

```bash
curl -s -H "Authorization: Bearer <access_token>" \
  -H "X-Region: cn" \
  https://<staging-api>/v1/notifications/devices \
  -X POST -H "Content-Type: application/json" \
  -d '{"deviceId":"dev_check","apnsToken":"<hex_token>","appVersion":"1.0.0","osVersion":"iOS 17.5","model":"iPhone"}'
```

预期：HTTP 200，`deviceId` / `apnsToken` 回显。

### 3.2 Mock 推送冒烟（无 Apple 证书）

```bash
kubectl port-forward -n staging svc/notification-svc 8008:80
curl -s -X POST localhost:8008/v1/debug/apns-ping \
  -H 'X-Region: cn' -H 'Content-Type: application/json' \
  -d '{"device_token":"<hex_token>","title":"INT-08","body":"mock push"}'
```

预期：`simulated: true`（`APNS_MOCK=true` 时）。

### 3.3 真 APNs

1. Helm / ExternalSecret 注入 Vault 密钥，设 `APNS_MOCK=false`。
2. 重启 notification-svc Pod。
3. 重复 3.2；预期 `simulated: false`，真机收到通知。

### 3.4 AI 完成静默下载

1. 真机提交 AI 任务后切到后台（或锁屏）。
2. 等待 ai-dispatch 完成 → Kafka `ai.events` → notification-svc 推送：
   - 静默：`content-available: 1` + `taskId` / `resultUrl`
   - 可见：标题「AI 任务完成」
3. 静默推送到达后，`SilentPushBackgroundHandler` 入队并提交 `BGAppRefreshTask`；若 AI Tab 已 bootstrap，`AITaskCoordinator` 状态变为 `succeeded`，下载协调器拉取结果。

调试：Xcode → Debug → Simulate Background Fetch；或观察 AI 进度页回到前台后结果已就绪。

---

## 4. 常见问题

| 现象 | 排查 |
| --- | --- |
| `didFailToRegisterForRemoteNotifications` | 模拟器不支持；检查 Push Capability / Profile |
| `NOTIF_TOKEN_INVALID` | Token 与 `APNS_SANDBOX` / 包类型不匹配 |
| 收到可见推送但无后台下载 | AI Tab 未打开过 → coordinator 未注册；或任务未 `track` |
| `APNs 失败率` 告警 | 查 Vault 密钥过期、Topic 与 Bundle ID 不一致 |

---

## 5. 相关代码

| 组件 | 路径 |
| --- | --- |
| HTTP/2 Sender | `services/notification-svc/internal/apns/http2_sender.go` |
| 端注册 | `ios/Packages/BabyCameraNotification/.../APNsTokenRegistrar.swift` |
| App 接线 | `ios/BabyCamera/App/NotificationIntegrationBridge.swift` |
| 静默处理 | `ios/Packages/BabyCameraNotification/.../SilentPushBackgroundHandler.swift` |
