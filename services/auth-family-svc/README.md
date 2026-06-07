# auth-family-svc

账号、家庭、宝宝档案微服务（T1.1 起：Apple ID 登录）。

## 快速启动

```bash
cd services/auth-family-svc
export SERVICE_NAME=auth-family-svc HTTP_PORT=8001 GRPC_PORT=9001
export MOCK_APPLE_VERIFY=true APPLE_AUTH_MOCK=true STORAGE_BACKEND=memory
make run
```

## 环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `SERVICE_NAME` | `auth-family-svc` | 服务名 |
| `HTTP_PORT` | `8001` | REST 端口 |
| `GRPC_PORT` | `9001` | gRPC 端口 |
| `STORAGE_BACKEND` | `memory` | `memory` 或 `postgres` |
| `DATABASE_URL` | （空） | PostgreSQL DSN（`STORAGE_BACKEND=postgres` 时必填） |
| `MOCK_APPLE_VERIFY` | `true` | **已废弃别名**；请用 `APPLE_AUTH_MOCK` |
| `APPLE_AUTH_MOCK` | `true` | `true` 时跳过 Apple JWKS 签名校验（开发/测试/E2E）；`false` 时走真实 JWKS |
| `APPLE_BUNDLE_ID` | （空） | 生产校验时必填；identityToken `aud` 须匹配 App Bundle ID（如 `com.babycamera.app`） |
| `MOCK_SMS_FIXED_CODE` | （空） | **mock 模式**：6 位固定验证码，所有 CN 手机号均适用（见 [tests/accounts/README.md](../../tests/accounts/README.md)） |
| `SMS_TEST_PHONES` | （空） | 测试号白名单，格式 `phone:code,phone:code`；**aliyun 模式**下白名单号码使用固定码且跳过真实短信 |
| `ALIYUN_SMS_ACCESS_KEY_ID` | （空） | `SMS_PROVIDER=aliyun` 时必填（Vault `.../auth-family/aliyun-sms`） |
| `ALIYUN_SMS_ACCESS_KEY_SECRET` | （空） | 同上 |
| `ALIYUN_SMS_SIGN_NAME` | （空） | 短信签名 |
| `ALIYUN_SMS_TEMPLATE_CODE_LOGIN` | （空） | 登录验证码模板 ID（变量 `{code}`） |
| `ALIYUN_SMS_REGION` | `cn-hangzhou` | dysmsapi 区域 |
| `JWT_SIGNING_SECRET` | `dev-only-change-me` | JWT 占位（T1.3 正式签发） |

### Apple 登录（INT-02）

| 模式 | 环境变量 | 行为 |
| --- | --- | --- |
| **mock**（默认） | `APPLE_AUTH_MOCK=true` | 跳过 JWKS 签名校验；`identityToken` 可为任意字符串或 unsigned JWT（E2E / smoke 兼容） |
| **live JWKS** | `APPLE_AUTH_MOCK=false` + `APPLE_BUNDLE_ID=com.babycamera.app` | 从 `https://appleid.apple.com/auth/keys` 拉取公钥，校验 RS256 签名、`iss`、`aud`、`exp` |

`MOCK_APPLE_VERIFY` 为历史别名，未设置 `APPLE_AUTH_MOCK` 时仍生效。

**Staging 切换**（`infra/staging/values/auth-family-svc.yaml`）：

```yaml
# Mock（默认，API E2E / 冒烟）
APPLE_AUTH_MOCK: "true"

# 真机 Sign in with Apple 闭环
APPLE_AUTH_MOCK: "false"
APPLE_BUNDLE_ID: com.babycamera.app
# 移除或忽略 MOCK_APPLE_VERIFY
```

本地 live 校验（需可访问 Apple JWKS，且使用真机或 ASC 沙盒账号签发的 identityToken）：

```bash
export APPLE_AUTH_MOCK=false APPLE_BUNDLE_ID=com.babycamera.app
export STORAGE_BACKEND=memory HTTP_PORT=8001 JWT_SIGNING_SECRET=dev-only-change-me
make run
```

#### ASC / Apple Developer 配置

1. [Apple Developer](https://developer.apple.com) → **Identifiers** → App ID `com.babycamera.app` → 启用 **Sign in with Apple**。
2. Xcode → Target **BabyCamera** → **Signing & Capabilities** → 添加 **Sign in with Apple**（仓库 entitlements 已含 `com.apple.developer.applesignin`）。
3. 服务端仅需 `APPLE_BUNDLE_ID`（native iOS 的 `aud` 即 Bundle ID）；`.p8` Service Key 用于服务端换 token（V1.1+），identityToken JWKS 校验无需私钥。
4. TestFlight / 真机使用 **Sandbox Apple ID**（App Store Connect → Users and Access → Sandbox）或生产 Apple ID；identityToken 均由 Apple 签发，JWKS 校验逻辑相同。

#### 真机沙盒测试步骤

1. **后端**：Staging 设 `APPLE_AUTH_MOCK=false`，`APPLE_BUNDLE_ID=com.babycamera.app`；确认 Pod 可出站访问 `appleid.apple.com`。
2. **iOS**：Scheme **BabyCamera-Staging**，真机安装（Development 或 TestFlight）；`Staging.xcconfig` 中 API 指向 Staging 网关。
3. 登录页点击 **通过 Apple 登录** → 系统 Sheet 选择沙盒 Apple ID → 授权。
4. 预期：返回 JWT，`isNewUser` 首次为 `true`；再次登录同一 Apple ID 为 `false`。
5. 失败排查：`AUTH_APPLE_INVALID` → 检查 Bundle ID 与 `APPLE_BUNDLE_ID` 一致；网络 → 查 auth-family-svc 日志 `apple jwks fetch`。

### 短信验证码（INT-01）

| 模式 | 环境变量 | 行为 |
| --- | --- | --- |
| **mock**（默认） | `SMS_PROVIDER=mock` + `MOCK_SMS_FIXED_CODE=123456` | 所有手机号写入固定码，日志输出，不发真实短信 |
| **aliyun** | `SMS_PROVIDER=aliyun` + Vault 凭据 + `SMS_TEST_PHONES` | 白名单 QA 号固定码且跳过短信；其他号码随机码 + 阿里云发码 |

**Staging 默认 mock**（`infra/staging/values/auth-family-svc.yaml`）。切换阿里云：

```yaml
# Helm / Deployment env
SMS_PROVIDER: aliyun
SMS_TEST_PHONES: "13800138001:123456,13800138002:123456,13800138003:123456"
# 移除或留空 MOCK_SMS_FIXED_CODE（aliyun 模式不作用于非白名单号码）
# Vault Agent 注入 secret/staging/cn/auth-family/aliyun-sms →
#   ALIYUN_SMS_ACCESS_KEY_ID, ALIYUN_SMS_ACCESS_KEY_SECRET,
#   ALIYUN_SMS_SIGN_NAME, ALIYUN_SMS_TEMPLATE_CODE_LOGIN
```

本地 mock 联调（与 E2E / smoke 兼容）：

```bash
export SMS_PROVIDER=mock MOCK_SMS_FIXED_CODE=123456 STORAGE_BACKEND=memory HTTP_PORT=8001
make run
```

本地验证 aliyun 配置（需有效凭据，勿提交密钥）：

```bash
export SMS_PROVIDER=aliyun
export SMS_TEST_PHONES='13800138001:123456'
export ALIYUN_SMS_ACCESS_KEY_ID=... ALIYUN_SMS_ACCESS_KEY_SECRET=...
export ALIYUN_SMS_SIGN_NAME=... ALIYUN_SMS_TEMPLATE_CODE_LOGIN=...
make run
# 白名单号发码后仍用 123456 登录；非白名单号收真实短信
```

### Staging 测试手机号（固定验证码）

测试账号池：[tests/accounts/test-accounts.yaml](../../tests/accounts/test-accounts.yaml)

| 用途 | 手机号 | 验证码（mock：`MOCK_SMS_FIXED_CODE=123456`；aliyun：见 `SMS_TEST_PHONES`） |
| --- | --- | --- |
| 主冒烟 / 管理员 | `13800138001` | `123456` |
| 家庭成员 E2E | `13800138002` | `123456` |
| 访客 | `13800138003` | `123456` |

```bash
# 本地联调
export SMS_PROVIDER=mock MOCK_SMS_FIXED_CODE=123456 STORAGE_BACKEND=memory HTTP_PORT=8001
make run

curl -s localhost:8001/v1/auth/phone/code \
  -H 'Content-Type: application/json' \
  -H 'X-Region: cn' -H 'X-App-Version: 1.0.0-staging' -H 'X-Device-Id: qa-device-iphone12-001' \
  -d '{"phone":"13800138001"}'

curl -s localhost:8001/v1/auth/phone/login \
  -H 'Content-Type: application/json' \
  -H 'X-Region: cn' -H 'X-App-Version: 1.0.0-staging' -H 'X-Device-Id: qa-device-iphone12-001' \
  -d '{"phone":"13800138001","code":"123456"}'
```

## API（T1.1）

### POST /v1/auth/apple

请求头：`X-Region`、`X-App-Version`、`X-Device-Id`

```bash
curl -s localhost:8001/v1/auth/apple \
  -H 'Content-Type: application/json' \
  -H 'X-Region: cn' \
  -H 'X-App-Version: 1.0.0' \
  -H 'X-Device-Id: dev-1' \
  -d '{"identityToken":"apple-sub-demo","authorizationCode":"c-1","nickname":"豆豆妈","region":"cn"}'
```

## 数据表

见 `migrations/001_users.up.sql`（`users`：`apple_sub` 唯一、`phone+region` 唯一、`last_seen_at` 索引）。

## 测试

```bash
make test
```

单元测试使用内存 `UserStore`；生产可配合 `infra/data/docker-compose.dev.yml` 启动 PostgreSQL 并设置 `STORAGE_BACKEND=postgres`。
