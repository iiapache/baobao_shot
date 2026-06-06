# Staging 环境拓扑与访问方式

> 任务 **T0.20** · 对齐 [infra/gateway/domains/mapping.yaml](../../infra/gateway/domains/mapping.yaml)、[contracts/openapi/openapi.yaml](../../contracts/openapi/openapi.yaml)

## 1. 拓扑概览

```text
                    Internet
                        │
                        ▼
              ┌─────────────────────┐
              │  APISIX Gateway LB  │  TLS 1.3 + HTTP/2
              │  namespace: gateway │
              └──────────┬──────────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
   auth-family-svc  media-upload-svc  feed-svc  …
         │               │               │
         └───────────────┴───────────────┘
                         │
    ┌────────────────────┼────────────────────┐
    ▼                    ▼                    ▼
 PostgreSQL          MongoDB              Redis
 (ack-cn / eks-os)   (ack-cn / eks-os)   (ack-cn / eks-os)
    │                    │
    └──────── Kafka ─────┘
                         │
                    OSS / S3 + CDN
```

## 2. 双区域 Staging 入口

| 区域 | 集群 | K8s 命名空间 | API 域名 | WebSocket | CDN |
| --- | --- | --- | --- | --- | --- |
| CN | ack-cn | `staging` | `staging-api-cn.example.com` | `staging-ws-cn.example.com` | `staging-cdn-cn.example.com` |
| OS | eks-os | `staging` | `staging-api-os.example.com` | `staging-ws-os.example.com` | `staging-cdn-os.example.com` |

生产域名占位对照：`example.com` → 上线后 `babygrowth.app`（见 gateway `domains/mapping.yaml`）。

### 2.1 必需请求头（OpenAPI `common.yaml`）

| Header | 示例 | 说明 |
| --- | --- | --- |
| `X-Region` | `cn` / `os` | 与账号区域一致 |
| `X-App-Version` | `1.0.0-staging` | 客户端版本 |
| `X-Device-Id` | `qa-device-001` | 设备唯一标识 |
| `Authorization` | `Bearer <accessToken>` | 除 `/v1/auth/*` 外必填 |

### 2.2 API 前缀

- 健康检查：`GET /health`
- 业务 API：`/v1/*`（网关透传，见 [design-api.md](../../docs/design-api.md) §2）
- WebSocket：`/ws/v1/events`（示例）

## 3. 访问方式

### 3.1 内网 / VPN（推荐 QA）

```bash
# 解析到 APISIX LB（由 INFRA 维护实际 IP）
export STAGING_API_CN=https://staging-api-cn.example.com
export STAGING_RESOLVE="staging-api-cn.example.com:443:<APISIX-LB-IP>"

curl -sS --resolve "$STAGING_RESOLVE" \
  -H "X-Region: cn" \
  -H "X-App-Version: 1.0.0-staging" \
  -H "X-Device-Id: qa-device-001" \
  "$STAGING_API_CN/health"
```

### 3.2 本地 Mock（后端未部署时）

P0 冒烟可在本机 Mock API 上跑通，无需 VPN：

```bash
cd tests/mocks && docker compose up -d mock-api
export BASE_URL=http://localhost:18080
../smoke/smoke.sh
```

后端联调三方时，额外启动 `mock-iap` / `mock-wechat` / `mock-ad` / `mock-audit` / `mock-ai`（见 [mocks/README.md](../mocks/README.md)）。

### 3.3 iOS TestFlight / 真机

| 项 | Staging 配置 |
| --- | --- |
| Bundle ID | 与 Apple Developer 测试 App 一致 |
| API Base URL | `staging-api-cn.example.com`（CN）或 `staging-api-os.example.com`（OS） |
| 测试账号 | [accounts/test-accounts.yaml](../accounts/test-accounts.yaml) |
| 三方 Mock | 后端 `values-staging.yaml` 将 outbound URL 指向 mocks 端口 |

### 3.4 CI / GitLab

- Pipeline stage：`deploy-staging`（见 [.gitlab-ci.yml](../../.gitlab-ci.yml)）
- ArgoCD Application：`hello-staging`（示例上游，微服务就绪后替换）
- 冒烟 Job 建议：`tests/smoke/smoke.sh`，`BASE_URL` 指向 staging 或 mock-api

## 4. 依赖服务（Staging 命名空间）

| 组件 | 说明 | 文档 |
| --- | --- | --- |
| PostgreSQL | 账号、家庭、订阅 | [infra/data/README.md](../../infra/data/README.md) |
| MongoDB | Feed、AI 任务元数据 | 同上 |
| Redis | 会话、限流、缓存 | 同上 |
| Kafka | 异步审核、AI 调度 | [infra/messaging/README.md](../../infra/messaging/README.md) |
| OSS / S3 | 媒体直传 | [infra/storage/README.md](../../infra/storage/README.md) |
| Vault | 三方 Key（测试 Key 与 Mock 二选一） | [infra/vault/](../../infra/vault/) |
| Observability | Prometheus / Grafana / Sentry | [infra/observability/README.md](../../infra/observability/README.md) |

## 5. Mock 三方注入点

后端 staging 部署时，将 outbound 地址指向 [tests/mocks](../mocks/) 对应服务（docker-compose 默认端口）：

| 三方 | Mock 服务 | 默认端口 | 后端消费方 |
| --- | --- | --- | --- |
| Apple IAP | `mock-iap` | 18081 | credit-sub-ad-svc |
| 微信 Open | `mock-wechat` | 18082 | auth-family-svc |
| 广告联盟 SSV | `mock-ad` | 18083 | credit-sub-ad-svc |
| 内容审核 | `mock-audit` | 18084 | audit-svc |
| AI 模型 | `mock-ai` | 18085 | ai-dispatch-svc |

## 6. 冒烟验收

```bash
# Mock 模式（默认，P0 可离线验收）
cd tests/mocks && docker compose up -d mock-api
cd ../smoke && ./smoke.sh

# Staging 模式（需 VPN + 测试账号）
export BASE_URL=https://staging-api-cn.example.com
export SMOKE_PHONE=13800138001
export SMOKE_CODE=123456
./smoke.sh
```

预期：登录 → 上传 init/complete（拍照 mock）→ 发布 post 全部 HTTP 200，`code=OK`。

## 7. 相关链接

- OpenAPI 契约：[contracts/openapi/openapi.yaml](../../contracts/openapi/openapi.yaml)
- 网关部署：[infra/gateway/README.md](../../infra/gateway/README.md)
- 测试账号池：[accounts/test-accounts.yaml](../accounts/test-accounts.yaml)
- 性能基线机型：[performance/device-matrix.md](../performance/device-matrix.md)
