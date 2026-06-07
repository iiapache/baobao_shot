# 测试账号池

> 数据源：[test-accounts.yaml](./test-accounts.yaml) · 对齐 OpenAPI `authPhoneSendCode` / `authPhoneLogin`

## 1. 账号状态

| 字段 | 含义 |
| --- | --- |
| `placeholder` | 尚未在 Staging 开通，仅 Mock / 文档占位 |
| `active` | 已激活，可用于 Staging 真机、冒烟、E2E |
| `disabled` | 停用，脚本应跳过 |

### 1.1 手机号账号（CN）

| ID | 手机号 | 角色 | status | 固定验证码 |
| --- | --- | --- | --- | --- |
| `qa-cn-admin-001` | `13800138001` | 家庭管理员 | **active** | `123456` |
| `qa-cn-member-002` | `13800138002` | 家庭成员 | placeholder | `123456` |
| `qa-cn-guest-003` | `13800138003` | 访客只读 | placeholder | `123456` |

主冒烟 / E2E 默认使用 **`qa-cn-admin-001`**。双用户家庭场景需额外激活 `qa-cn-member-002`（邀请码 join 流程）。

Apple / 微信 / IAP 沙盒条目仍为 `placeholder`，见 Vault（`infra/accounts/THIRD_PARTY_ACCOUNTS.md`）。

## 2. Staging 固定验证码（`123456`）

Staging 与本地 Mock 均支持 **固定 6 位验证码**，无需等待真实短信。

| 环境 | 机制 | 配置位置 |
| --- | --- | --- |
| 本地 Mock API | mock 接受任意 code | `tests/mocks/api/mock_server.py` |
| auth-family-svc（Staging / 本地联调） | `SMS_PROVIDER=mock` + `MOCK_SMS_FIXED_CODE=123456` | 见 §3 |
| 阿里云短信（INT-01） | `SMS_PROVIDER=aliyun` + Vault 凭据 + `SMS_TEST_PHONES` 白名单 | [auth-family-svc README](../../services/auth-family-svc/README.md) §短信验证码 |

**auth-family-svc 行为：**

- **mock 模式**（Staging 默认）：`MOCK_SMS_FIXED_CODE` 为 6 位数字时，所有合法 CN 手机号均写入该固定码。
- **aliyun 模式**：`SMS_TEST_PHONES` 白名单号码（如 `13800138001:123456`）写入固定码且跳过真实短信；其他号码随机码并经阿里云发送。

## 3. Staging 激活步骤

### 3.1 部署 auth-family-svc（Staging 命名空间）

在 Deployment / Helm values 中设置：

```yaml
env:
  - name: ENVIRONMENT
    value: staging
  - name: SMS_PROVIDER
    value: mock
  - name: MOCK_SMS_FIXED_CODE
    value: "123456"
  - name: SMS_TEST_PHONES
    value: "13800138001:123456,13800138002:123456,13800138003:123456"
  - name: STORAGE_BACKEND
    value: postgres
  # DATABASE_URL 或 Vault 注入，见 examples/auth-family-deployment.yaml
```

本地联调 auth-family-svc：

```bash
cd services/auth-family-svc
export SMS_PROVIDER=mock MOCK_SMS_FIXED_CODE=123456 HTTP_PORT=8001 STORAGE_BACKEND=memory
make run
```

### 3.2 导出脚本环境变量

```bash
# 打印 smoke / e2e 所需变量并校验主账号 status=active
./tests/accounts/activate-staging.sh

# 写入 staging.env（gitignore 友好，可 source）
./tests/accounts/activate-staging.sh --write-env
source tests/accounts/staging.env
```

### 3.3 真机 / TestFlight 登录

1. App 使用 **Staging** Scheme（API → `staging-api-cn.example.com` 或实际域名）
2. 输入手机号 **`13800138001`**
3. 点击获取验证码 → 输入 **`123456`**
4. 请求头需带 `X-Region: cn`、`X-Device-Id`（见 [device-matrix](../performance/device-matrix.md)）

详见 [docs/qa/TESTFLIGHT_USER_GUIDE.md](../../docs/qa/TESTFLIGHT_USER_GUIDE.md)。

## 4. 冒烟 / E2E 环境变量映射

与 [test-accounts.yaml](./test-accounts.yaml) `usage.smoke_script` 对齐：

| 变量 | 默认值 | 来源 |
| --- | --- | --- |
| `SMOKE_PHONE` / `E2E_ADMIN_PHONE` | `13800138001` | `phone_accounts[0].phone` |
| `SMOKE_CODE` / `E2E_ADMIN_CODE` | `123456` | `phone_accounts[0].sms_code_mock` |
| `SMOKE_DEVICE_ID` / `E2E_DEVICE_ID` | `qa-device-iphone12-001` | `devices[0].device_id` |
| `E2E_MEMBER_PHONE` | `13800138002` | `phone_accounts[1].phone` |
| `E2E_MEMBER_CODE` | `123456` | `phone_accounts[1].sms_code_mock` |

示例文件：

- [../smoke/smoke.env.example](../smoke/smoke.env.example)
- [../e2e/e2e.env.example](../e2e/e2e.env.example)
- [staging.env.example](./staging.env.example)

## 5. 验证命令

### 5.1 Mock 模式（离线，无需 Staging）

```bash
cd tests/mocks && docker compose up -d mock-api
cd ../smoke && ./smoke.sh
cd ../e2e && ./e2e.sh
```

### 5.2 Staging 模式（需 VPN + auth-family 已设 MOCK_SMS_FIXED_CODE）

```bash
source tests/accounts/staging.env   # 或 activate-staging.sh --write-env 后 source

curl -sS --resolve "${STAGING_RESOLVE}" \
  -X POST "${BASE_URL}/v1/auth/phone/code" \
  -H "Content-Type: application/json" \
  -H "X-Region: cn" \
  -H "X-App-Version: 1.0.0-staging" \
  -H "X-Device-Id: qa-device-iphone12-001" \
  -d '{"phone":"13800138001"}'

curl -sS --resolve "${STAGING_RESOLVE}" \
  -X POST "${BASE_URL}/v1/auth/phone/login" \
  -H "Content-Type: application/json" \
  -H "X-Region: cn" \
  -H "X-App-Version: 1.0.0-staging" \
  -H "X-Device-Id: qa-device-iphone12-001" \
  -d '{"phone":"13800138001","code":"123456"}'

cd tests/smoke && ./smoke.sh
cd ../e2e && ./e2e.sh
```

### 5.3 配置自检

```bash
./tests/accounts/activate-staging.sh --check
```

## 6. 轮换策略

见 `test-accounts.yaml` → `usage.rotation_policy`：每季度轮换手机号；变更后同步更新 smoke/e2e 默认值与本 README 表格。

## 7. 相关链接

- [tests/staging/README.md](../staging/README.md) — Staging 拓扑与 VPN 访问
- [services/auth-family-svc/README.md](../../services/auth-family-svc/README.md) — `MOCK_SMS_FIXED_CODE`
- [infra/accounts/THIRD_PARTY_ACCOUNTS.md](../../infra/accounts/THIRD_PARTY_ACCOUNTS.md) — 三方凭据 Vault 路径
