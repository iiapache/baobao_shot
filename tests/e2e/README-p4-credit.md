# P4 积分/订阅/广告 端到端回归（T4.17）

> 流程：**IAP 充值 → AI hold/commit/release → 签到/激励/邀请 → 订阅购买 → 关广告/关水印 → grace/退订/refund**  
> 服务：`credit-sub-ad-svc` · `iap-callback-svc` · 契约：[contracts/openapi/paths/credits.yaml](../../contracts/openapi/paths/credits.yaml) · [subscriptions.yaml](../../contracts/openapi/paths/subscriptions.yaml)

## 目录

```text
tests/e2e/
├── README-p4-credit.md                              # 本文件
├── p4-e2e.sh                                        # API E2E shell（mock / staging）
├── p4-credit.env.example                            # P4 环境变量模板
├── baobao-p4-credit-e2e.postman_collection.json     # Postman / Newman 集合
tests/mocks/api/
├── mock_server.py                                   # Python fallback（含 P4 状态机）
└── mappings/34-*.json … 42-*.json                   # WireMock P4 映射
```

## 快速开始（Mock 模式）

```bash
# 1. 启动 Mock API（推荐 Python fallback — 含完整积分/订阅状态机）
cd tests/mocks/api && python3 mock_server.py
# 或 Docker WireMock（静态场景，无跨步骤余额联动）：
# cd tests/mocks && docker compose up -d mock-api

# 2. 跑 P4 E2E
cd ../../e2e && chmod +x p4-e2e.sh && ./p4-e2e.sh
```

预期末尾：

`P4 Credit E2E PASSED: iap · ai hold/commit/release · sign-in · ad · invite · sub · grace/refund · negative balance`

## Postman / Newman

```bash
npx --yes newman run tests/e2e/baobao-p4-credit-e2e.postman_collection.json \
  --env-var baseUrl=http://localhost:18080
```

## 场景与 Mock 触发

| 场景 | 触发方式 | 预期 |
| --- | --- | --- |
| A 余额/费率/商品 | `GET /v1/credits/balance` 等 | 注册赠分 100 · rates · products |
| B IAP 充值 | `POST /v1/credits/iap-verify` | +100 · duplicate 幂等 |
| C AI commit | `POST /v1/ai/tasks` → poll | `credit_held` → `succeeded` · 余额扣减 |
| D AI release | Header `X-E2E-Scenario: model_failed` | `failed` · 退还积分 |
| E 负余额 | Header `X-E2E-Scenario: insufficient_balance` | `balanceAfter < 0` |
| F 签到 | `POST /v1/credits/sign-in` ×2 | 连签递增 · 409 `CREDIT_SIGN_IN_DONE` |
| G 激励广告 | 端侧 `POST /v1/credits/ad-reward` + 穿山甲 callback | +5 · 伪造签名 403 |
| H 邀请赠分 | 成员 `POST .../join` | 管理员 ledger `invite` +50 |
| I 订阅购买/退订 | `POST /v1/subscriptions/iap-verify` → `POST /v1/e2e/subscriptions/event` | active → refunded · removeAds false |
| J 续订 grace | event `grace` 或 Header `X-E2E-Scenario: sub_grace` | state=grace · 权益保留 |

Mock-only 端点（Python fallback）：`POST /v1/e2e/subscriptions/event` body `{"event":"grace"|"refund"|"expire"}`。

## 步骤与 OpenAPI operationId

| # | 步骤 | Method | Path | operationId |
| --- | --- | --- | --- | --- |
| 0 | 健康检查 | GET | `/health` | — |
| 1 | 登录 | POST | `/v1/auth/phone/login` | authPhoneLogin |
| 2 | 余额 | GET | `/v1/credits/balance` | creditsGetBalance |
| 3 | 费率 | GET | `/v1/credits/rates` | creditsGetRates |
| 4 | IAP 充值 | POST | `/v1/credits/iap-verify` | creditsIapVerify |
| 5 | AI 任务 | POST/GET | `/v1/ai/tasks` | aiCreateTask / aiGetTask |
| 6 | 签到 | POST | `/v1/credits/sign-in` | creditsSignIn |
| 7 | 激励广告 | POST | `/v1/credits/ad-reward` | creditsAdReward |
| 8 | 订阅校验 | POST | `/v1/subscriptions/iap-verify` | subscriptionsIapVerify |
| 9 | 订阅状态 | GET | `/v1/subscriptions/me` | subscriptionsGetMe |
| 10 | 商品列表 | GET | `/v1/subscriptions/products` | subscriptionsListProducts |

## 关联 Mock 映射

P4 新增 WireMock：`tests/mocks/api/mappings/34-*.json` … `42-*.json`。  
Python fallback：`tests/mocks/api/mock_server.py`（`CREDIT_USERS` 状态机 · AI hold/release 联动）。

IAP 沙盒占位：[tests/accounts/test-accounts.yaml](../accounts/test-accounts.yaml) §iap_sandbox。

## 单元 / 服务测试（补充验证）

```bash
# credit-sub-ad-svc（账本、saga、IAP、订阅、签到、广告）
cd services/credit-sub-ad-svc && go test ./...

# iap-callback-svc（Apple ASN v2 · REFUND/REVOKE）
cd services/iap-callback-svc && go test ./...

# iOS Credit 包
cd ios/Packages/BabyCameraCredit && swift test
```

## Staging 模式

```bash
export BASE_URL=https://staging-api-cn.example.com
export E2E_ADMIN_CODE=<真实验证码>
./p4-e2e.sh
```

> Staging 需真实 credit-sub-ad-svc；Mock 专用 Header 与 `/v1/e2e/*` 在 staging 不可用。

## 验收对照（T4.17）

| 验收项 | 实现 |
| --- | --- |
| IAP verify mock + 幂等 | Scenario B · 映射 `37` |
| AI hold/commit/release | Scenario C/D · mock_server `_ai_hold_credits` / `_ai_release_credits` |
| 签到/激励/邀请 | Scenario F/G/H |
| 订阅 → 关广告/关水印 | Scenario I · `removeAds` / `brandWatermarkRemovable` |
| 退订/refund | Scenario I · e2e event `refund` |
| 续订 grace | Scenario J · 映射 `42` · e2e event `grace` |
| 负余额边界 | Scenario E · `insufficient_balance` |
| Postman 集合 | `baobao-p4-credit-e2e.postman_collection.json` |

## 相关任务

- T4.1–T4.10：credit-sub-ad-svc 后端
- T4.11–T4.16：iOS Credit / IAP / Subscription / AdManager / AIPlay 联调
- T4.17：本目录
