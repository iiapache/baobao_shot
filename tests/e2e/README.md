# P1 端到端回归（T1.20）

> 流程：**登录 → 创建家庭 → 邀请家人 → 创建宝宝 → 注销**  
> 服务：`auth-family-svc` · 契约：[contracts/openapi/openapi.yaml](../../contracts/openapi/openapi.yaml)

## 目录

```text
tests/e2e/
├── README.md                              # 本文件
├── e2e.sh                                 # API E2E shell（mock / staging）
├── e2e.env.example                        # 环境变量模板
├── baobao-p1-e2e.postman_collection.json  # Postman / Newman 集合
└── ios/
    └── P1AccountFamilyE2ETests.swift      # XCUITest（mock 登录/API）
```

## 快速开始（Mock 模式）

```bash
# 1. 启动 Mock API（WireMock 或 Python fallback）
cd tests/mocks && docker compose up -d mock-api
# 无 Docker：python3 api/mock_server.py

# 2. 跑 API E2E
cd ../e2e && chmod +x e2e.sh && ./e2e.sh
```

预期末尾：`P1 E2E PASSED: login → family → invite → baby → delete account`。

## Postman / Newman

导入 [baobao-p1-e2e.postman_collection.json](./baobao-p1-e2e.postman_collection.json)，运行 Folder **P1 E2E**。

Newman 示例：

```bash
npx --yes newman run tests/e2e/baobao-p1-e2e.postman_collection.json \
  --env-var baseUrl=http://localhost:18080
```

## XCUITest（iOS · mock 模式）

XCUITest 覆盖单用户端侧路径：手机号登录 → 新手引导（创建家庭 + 宝宝 + 同意书）→ 注销账号。  
「邀请家人」双用户场景由 API E2E / Postman 覆盖（主 App Shell 尚未接入家庭成员页导航）。

```bash
cd ios
xcodebuild test \
  -scheme BabyCamera \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:BabyCameraUITests/P1AccountFamilyE2ETests
```

启动参数 `-UITesting` 会自动注入 `MockURLProtocol` 响应，无需真实后端。

## 步骤与 OpenAPI operationId

| # | 步骤 | Method | Path | operationId |
| --- | --- | --- | --- | --- |
| 0 | 健康检查 | GET | `/health` | — |
| 1-2 | 管理员登录 | POST | `/v1/auth/phone/code` → `/login` | authPhoneSendCode → authPhoneLogin |
| 3 | 创建家庭 | POST | `/v1/families` | familyCreate |
| 4 | 生成邀请码 | POST | `/v1/families/{id}/invitations` | familyCreateInvitation |
| 5-6 | 成员登录 | POST | `/v1/auth/phone/code` → `/login` | authPhoneSendCode → authPhoneLogin |
| 7 | 加入家庭 | POST | `/v1/invitations/{code}/join` | familyJoinByInvitation |
| 8 | 成员列表 | GET | `/v1/families/{id}/members` | familyListMembers |
| 9 | 创建宝宝 | POST | `/v1/families/{id}/babies` | babyCreate |
| 10 | 注销账号 | DELETE | `/v1/account` | accountDelete |

## Staging 模式

```bash
export BASE_URL=https://staging-api-cn.example.com
export STAGING_RESOLVE="staging-api-cn.example.com:443:<LB-IP>"
export E2E_ADMIN_CODE=<真实验证码>
export E2E_MEMBER_CODE=<真实验证码>
./e2e.sh
```

账号占位见 [accounts/test-accounts.yaml](../accounts/test-accounts.yaml)。

## 验收对照（T1.20）

| 验收项 | 实现 |
| --- | --- |
| XCUITest 用例 | `tests/e2e/ios/P1AccountFamilyE2ETests.swift` + `BabyCameraUITests` target |
| Postman 集合 | `baobao-p1-e2e.postman_collection.json`（11 步 happy path） |
| 对齐 T0.20 基础设施 | 复用 `tests/mocks/`、`tests/accounts/`、OpenAPI operationId |
| staging 回归 | `e2e.env` + `BASE_URL` 切换 |
| 邀请家人 | API/Postman 双用户；XCUITest 见 README 说明 |

## 相关 Mock 映射

P1 新增 WireMock 映射：`tests/mocks/api/mappings/07-*.json` … `15-*.json`、`02b-auth-phone-login-member.json`。

## P3 AI E2E（T3.26）

见 [README-p3-ai.md](./README-p3-ai.md) · `./p3-e2e.sh` · `baobao-p3-ai-e2e.postman_collection.json`

## P4 积分/订阅/广告 E2E（T4.17）

见 [README-p4-credit.md](./README-p4-credit.md) · `./p4-e2e.sh` · `baobao-p4-credit-e2e.postman_collection.json`

## P7 性能压测基准（T7.6）

见 [../performance/README.md](../performance/README.md) · `benchmark-feed.sh` · `benchmark-ai-mock.sh` · `ios/PerformanceBenchmarkTests.swift`
