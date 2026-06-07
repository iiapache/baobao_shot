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
| 测试账号 | [accounts/README.md](../accounts/README.md) · [test-accounts.yaml](../accounts/test-accounts.yaml) |
| 短信固定码 | auth-family-svc `MOCK_SMS_FIXED_CODE=123456`（见 accounts README §3） |
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

## 5. Mock 三方注入点（ENV-06）

后端 staging 部署时，将 outbound 地址指向 [tests/mocks](../mocks/) 对应服务。

### 5.1 映射表

| 三方 | Mock 服务 | 本地端口 | K8s Service URL | 消费方 | 关键 env |
| --- | --- | --- | --- | --- | --- |
| Apple IAP | `mock-iap` | 18081 | `http://mock-iap.third-party-mocks.svc.cluster.local:8080` | credit-sub-ad-svc, iap-callback-svc | `APPLE_IAP_SERVER_API_BASE`, `APPLE_IAP_VERIFY_URL` |
| 微信 Open | `mock-wechat` | 18082 | `http://mock-wechat.third-party-mocks.svc.cluster.local:8080` | auth-family-svc | `WECHAT_OPEN_API_BASE` |
| 广告联盟 SSV | `mock-ad` | 18083 | `http://mock-ad.third-party-mocks.svc.cluster.local:8080` | credit-sub-ad-svc | `PANGLE_SECURITY_KEY`, `GDT_SECRET_KEY` |
| 内容审核 | `mock-audit` | 18084 | `http://mock-audit.third-party-mocks.svc.cluster.local:8080` | audit-svc, feed-svc, ai-dispatch-svc | `ALIYUN_GREEN_MOCK_MODE`, `ALIYUN_GREEN_ENDPOINT`, `AUDIT_SVC_URL` |
| AI 模型 | `mock-ai` | 18085 | `http://mock-ai.third-party-mocks.svc.cluster.local:8080` | ai-dispatch-svc | `DASHSCOPE_ENDPOINT`, `OPENAI_API_BASE`, `OS_ADAPTER_MOCK_MODE` |

权威配置：[infra/staging/outbound-mapping.yaml](../../infra/staging/outbound-mapping.yaml)

### 5.2 docker-compose 一键启动

```bash
cd tests/mocks

# 仅 API Mock（P0 冒烟）
docker compose up -d mock-api

# 全部三方 Mock（outbound 联调）
docker compose up -d

# 验证
../../tests/staging/verify-outbound.sh --local
```

本地开发时微服务 env 可指向 `http://host.docker.internal:1808x`（Docker Desktop）或 `http://localhost:1808x`。

### 5.3 K8s staging 注入

```bash
# 同步映射 + 部署 WireMock
./infra/staging/scripts/sync-mock-mappings.sh
helm upgrade --install third-party-mocks infra/k8s/charts/third-party-mocks \
  -n staging -f infra/k8s/clusters/ack-cn/staging-third-party-mocks-values.yaml

# 微服务 values 片段（合并到各服务 Helm release）
# infra/staging/values/{ack-cn-outbound,auth-family-svc,credit-sub-ad-svc,audit-svc,ai-dispatch-svc}.yaml
```

详见 [infra/staging/README.md](../../infra/staging/README.md)。

## 6. 冒烟验收

### 6.1 ENV-03 · Staging 微服务部署

```bash
# 1) 部署（需 VPN + kubectl 上下文 ack-cn / eks-os）
./infra/staging/scripts/deploy-staging.sh --cluster ack-cn
./infra/staging/scripts/deploy-staging.sh --cluster ack-cn --image-tag "${CI_COMMIT_SHORT_SHA:-staging}"

# 可选：ArgoCD GitOps
kubectl apply -f infra/k8s/argocd/applications/baobao-staging-ack-cn.yaml
./infra/staging/scripts/deploy-staging.sh --cluster ack-cn --argocd

# 2) 健康检查
./tests/staging/smoke-staging.sh --static-only          # 本地无 VPN：manifest 静态检查
./tests/staging/smoke-staging.sh --cluster ack-cn       # 网关 GET /health → 200
./tests/staging/smoke-staging.sh --cluster ack-cn --resolve <APISIX-LB-IP>
./tests/staging/smoke-staging.sh --cluster ack-cn --full-smoke  # + tests/smoke/smoke.sh

# 3) 等价 curl
export STAGING_API_CN=https://staging-api-cn.example.com
export STAGING_RESOLVE="staging-api-cn.example.com:443:<APISIX-LB-IP>"
curl -sS --resolve "$STAGING_RESOLVE" \
  -H "X-Region: cn" -H "X-App-Version: 1.0.0-staging" -H "X-Device-Id: qa-device-001" \
  "$STAGING_API_CN/health"
```

部署产物：

| 组件 | 路径 |
| --- | --- |
| 通用微服务 chart | `infra/k8s/charts/microservice/` |
| Staging umbrella chart | `infra/k8s/charts/baobao-staging/` |
| 集群 values | `infra/k8s/clusters/{ack-cn,eks-os}/staging-services-values.yaml` |
| 部署脚本 | `infra/staging/scripts/deploy-staging.sh` |
| 网关 `/health` 路由 | `infra/gateway/routes/staging-api-health.yaml` |
| ArgoCD Application | `infra/k8s/argocd/applications/baobao-staging-*.yaml` |
| ApplicationSet | `infra/argocd/applicationsets/baobao-staging.yaml` |

微服务清单（staging 命名空间）：`auth-family-svc`、`media-svc`、`feed-svc`、`audit-svc`、`ai-dispatch-svc`、`credit-sub-ad-svc`。

### 6.2 Outbound / Mock / 端到端冒烟

```bash
# Outbound Mock 健康（ENV-06）
./tests/staging/verify-outbound.sh --local
./tests/staging/verify-outbound.sh --k8s -n staging

# Mock 模式（默认，P0 可离线验收）
cd tests/mocks && docker compose up -d mock-api
cd ../smoke && ./smoke.sh

# Staging 模式（需 VPN + auth-family MOCK_SMS_FIXED_CODE=123456）
./accounts/activate-staging.sh --write-env && source accounts/staging.env
# 或手动：
export BASE_URL=https://staging-api-cn.example.com
export SMOKE_PHONE=13800138001
export SMOKE_CODE=123456
./smoke.sh
```

预期：`verify-outbound.sh` 全部 `[PASS]`；`smoke-staging.sh --cluster ack-cn` 网关 `/health` HTTP 200；登录 → 上传 init/complete（拍照 mock）→ 发布 post 全部 HTTP 200，`code=OK`。

## 7. 相关链接

- OpenAPI 契约：[contracts/openapi/openapi.yaml](../../contracts/openapi/openapi.yaml)
- 网关部署：[infra/gateway/README.md](../../infra/gateway/README.md)
- 测试账号池：[accounts/README.md](../accounts/README.md) · [test-accounts.yaml](../accounts/test-accounts.yaml)
- 性能基线机型：[performance/device-matrix.md](../performance/device-matrix.md)
