# Staging 三方 Outbound 注入（ENV-06）

> 将 staging 微服务的 outbound 调用指向 [tests/mocks](../../tests/mocks/) WireMock，或沙盒三方。  
> 权威映射表：[outbound-mapping.yaml](./outbound-mapping.yaml)

## 1. 架构

```text
staging 命名空间
├── third-party-mocks (Helm)     mock-iap / mock-wechat / mock-ad / mock-audit / mock-ai
├── auth-family-svc            WECHAT_OPEN_API_BASE → mock-wechat
├── credit-sub-ad-svc          IAP / 广告验签 → mock-iap / mock-ad
├── audit-svc                  ALIYUN_GREEN_* → mock-audit（或内部 MOCK_MODE）
├── ai-dispatch-svc            DASHSCOPE / OPENAI → mock-ai
└── notification-svc           APNS_MOCK=true（默认）；真 APNs 见 §4.4
```

## 2. 本地一键启动 Mocks

```bash
cd tests/mocks

# 仅 API（P0 冒烟）
docker compose up -d mock-api

# 全部三方 Mock（outbound 联调）
docker compose up -d

# 健康检查
../../tests/staging/verify-outbound.sh --local
```

宿主机端口见 [outbound-mapping.yaml](./outbound-mapping.yaml) `local` 段。

## 3. K8s 部署 Mocks

```bash
# 1) 同步 WireMock 映射到 chart bundle（首次或 mappings 变更后）
./infra/staging/scripts/sync-mock-mappings.sh

# 2) 安装到 staging 命名空间
cd infra/k8s/charts/third-party-mocks
helm dependency update
helm upgrade --install third-party-mocks . \
  -n staging \
  -f ../../clusters/ack-cn/staging-third-party-mocks-values.yaml

# 3) 验证 Pod 与 outbound 可达
../../tests/staging/verify-outbound.sh --k8s --namespace staging
```

EKS 新加坡将 values 文件换为 `clusters/eks-os/staging-third-party-mocks-values.yaml`。

## 3.1 ENV-03 · 微服务一键部署

```bash
# ACK 中国（含 third-party-mocks + 6 微服务 + 网关路由）
./infra/staging/scripts/deploy-staging.sh --cluster ack-cn

# 指定镜像 tag（CI 构建产物）
IMAGE_TAG=abc1234 ./infra/staging/scripts/deploy-staging.sh --cluster ack-cn

# 健康检查
tests/staging/smoke-staging.sh --static-only
tests/staging/smoke-staging.sh --cluster ack-cn --resolve <APISIX-LB-IP>
```

ArgoCD：`kubectl apply -f infra/k8s/argocd/applications/baobao-staging-ack-cn.yaml`

## 4. 微服务 Outbound 注入

各服务 staging values 片段位于 `infra/staging/values/`。部署微服务 Helm chart 时合并：

```bash
helm upgrade --install credit-sub-ad-svc ./charts/credit-sub-ad-svc \
  -n staging \
  -f infra/k8s/clusters/ack-cn/cluster-values.yaml \
  -f infra/staging/values/ack-cn-outbound.yaml \
  -f infra/staging/values/credit-sub-ad-svc.yaml
```

### 4.1 环境变量速查

| 消费方 | 关键 env | Staging 指向 |
| --- | --- | --- |
| auth-family-svc | `APPLE_AUTH_MOCK`, `APPLE_BUNDLE_ID`, `WECHAT_OPEN_API_BASE` | `true` / `com.babycamera.app` / mock-wechat K8s URL |
| credit-sub-ad-svc | `PANGLE_SECURITY_KEY`, `GDT_SECRET_KEY` | staging 测试密钥（配合 mock-ad） |
| audit-svc | `ALIYUN_GREEN_MOCK_MODE`, `ALIYUN_GREEN_ENDPOINT` | 默认 `true`（进程内 mock）；HTTP 走 mock-audit 见 §4.3 |
| ai-dispatch-svc | `CN_ADAPTER_MOCK_MODE`, `DASHSCOPE_*`, `BYTEDANCE_*`, `OPENAI_*`, `OS_ADAPTER_MOCK_MODE` | mock-ai URL + staging 测试密钥（默认）；真厂商见 §4.2 |
| feed-svc | `AUDIT_SVC_URL` | 集群内 audit-svc（其自身连 mock-audit） |
| notification-svc | `APNS_MOCK`, `APNS_SANDBOX`, `APNS_TOPIC`, `KAFKA_BROKERS` | 默认 `APNS_MOCK=true`；真 APNs 见 §4.4 |

完整映射见 [outbound-mapping.yaml](./outbound-mapping.yaml)。

### 4.2 INT-06 · 启用真 AI 厂商（Staging / 生产）

Staging **默认**将 CN/OS adapter 的 HTTP 客户端指向集群内 `mock-ai` WireMock（`CN_ADAPTER_MOCK_MODE=false` + mock 密钥）。  
要走 **DashScope / 火山 Seedream / OpenAI** 真厂商时：

1. 从 Vault 读取凭据（见 `infra/vault/secrets-template/ai-dispatch.env.example`）。
2. 覆盖 ai-dispatch-svc 环境变量（Helm `extraEnv` 或 ExternalSecret）：

| 区域 | 变量 | 真厂商示例 |
| --- | --- | --- |
| CN 宫崎骏风 | `BYTEDANCE_ENDPOINT` | `https://visual.volcengineapi.com` |
| CN 宫崎骏风 | `BYTEDANCE_API_KEY` / `BYTEDANCE_API_SECRET` | Vault `.../ai-dispatch/bytedance` |
| CN 通义万相 | `DASHSCOPE_ENDPOINT` | `https://dashscope.aliyuncs.com` |
| CN 通义万相 | `DASHSCOPE_API_KEY` | Vault `.../ai-dispatch/alibaba-dashscope` |
| OS | `OPENAI_API_BASE` | `https://api.openai.com/v1` |
| OS | `OPENAI_API_KEY` | Vault `.../ai-dispatch/openai` |

3. 保持 `CN_ADAPTER_MOCK_MODE=false`、`OS_ADAPTER_MOCK_MODE=false`（使用 HTTP 客户端而非进程内 MockClient）。
4. 备案号须与 COMP-01 一致：挂载 `compliance/algorithm-filing/filings.yaml` 或设置 `ALGORITHM_FILING_PATH`；缺号时 CN 玩法路由拒绝（T7.1）。

本地纯 stub（无 outbound HTTP）：

```bash
export CN_ADAPTER_MOCK_MODE=true
export OS_ADAPTER_MOCK_MODE=true
make -C services/ai-dispatch-svc run
```

### 4.3 INT-07 · 启用真内容审核（Staging / 生产）

Staging **默认** `ALIYUN_GREEN_MOCK_MODE=true`（进程内 reject 标记规则，与 E2E `reject_spam` 一致）。  
要走 **mock-audit WireMock** 或 **阿里云 Green 真厂商** 时：

| 模式 | 变量 | 说明 |
| --- | --- | --- |
| 进程内 mock（默认） | `ALIYUN_GREEN_MOCK_MODE=true` | 无需 outbound；文本含 `reject_spam` / `reject_porn` 等即拒 |
| mock-audit HTTP | `ALIYUN_GREEN_MOCK_MODE=false` + `ALIYUN_GREEN_ENDPOINT=http://mock-audit.third-party-mocks.svc.cluster.local:8080` | 走 WireMock `/green/text/scan` 等 |
| 真厂商 SDK | `ALIYUN_GREEN_MOCK_MODE=false` + `ALIYUN_GREEN_ACCESS_KEY_ID/SECRET` + `ALIYUN_GREEN_REGION` | Vault `secret/data/{env}/cn/audit/aliyun-green`；图像需可公网访问的 `ALIYUN_GREEN_OBJECT_URL_PREFIX` |

消费方（feed-svc / ai-dispatch-svc）只需 `AUDIT_SVC_URL` 指向集群内 audit-svc；Green 凭据仅在 audit-svc 侧配置。

本地 mock-audit + HTTP 客户端：

```bash
cd tests/mocks && docker compose up -d mock-audit
export ALIYUN_GREEN_MOCK_MODE=false
export ALIYUN_GREEN_ENDPOINT=http://localhost:18084
make -C services/audit-svc run
```

### 4.4 INT-08 · 启用真 APNs（Staging / 生产）

Staging **默认** `APNS_MOCK=true`（不连 Apple，便于 CI / 无证书环境）。真机推送需：

1. 在 Apple Developer 启用 Push Notifications，导出 `.p8` Auth Key。
2. 从 Vault 读取凭据（`infra/vault/secrets-template/notification.env.example`）。
3. 覆盖 notification-svc 环境变量：

| 变量 | 说明 |
| --- | --- |
| `APNS_MOCK` | `false` 启用 HTTP/2 真发送 |
| `APNS_SANDBOX` | Staging / Debug 包用 `true`；TestFlight / App Store 用 `false` |
| `APNS_TOPIC` | iOS Bundle ID，如 `com.babycamera.app` |
| `APNS_KEY_ID` | Auth Key ID |
| `APNS_TEAM_ID` | Apple Team ID |
| `APNS_PRIVATE_KEY_PEM` | `.p8` PEM 全文 |

4. 端侧使用 `BabyCamera-Staging` Scheme，登录后自动注册 Token 到 `POST /v1/notifications/devices`。
5. AI 任务完成时 Kafka `ai.events` → notification-svc 发送静默 + 可见双推送；端侧 `NotificationBootstrap` 触发后台下载。

本地 mock 模式：

```bash
export APNS_MOCK=true
make -C services/notification-svc run
curl -s -X POST localhost:8008/v1/debug/apns-ping \
  -H 'X-Region: cn' -H 'Content-Type: application/json' \
  -d '{"device_token":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab","title":"smoke","body":"mock"}'
```

真机联调步骤见 [`ios/docs/APNS_STAGING_TESTING.md`](../../ios/docs/APNS_STAGING_TESTING.md)。

## 5. 验收

```bash
# 本地 mocks 健康 + 抽样路径
tests/staging/verify-outbound.sh --local

# K8s 集群内（需 kubectl 上下文）
tests/staging/verify-outbound.sh --k8s -n staging

# ENV-03：Staging 微服务部署与健康检查
./infra/staging/scripts/deploy-staging.sh --cluster ack-cn
tests/staging/smoke-staging.sh --cluster ack-cn --resolve <APISIX-LB-IP>

# 端到端冒烟（mock-api）
cd tests/mocks && docker compose up -d mock-api
cd ../smoke && ./smoke.sh
```

预期：`verify-outbound.sh` 全部 `[PASS]`；`smoke.sh` 登录 → 上传 → 发布 HTTP 200。

## 6. 相关文档

- [tests/staging/README.md](../../tests/staging/README.md) §5 Mock 注入点
- [tests/mocks/README.md](../../tests/mocks/README.md)
- [infra/k8s/charts/third-party-mocks/README.md](../k8s/charts/third-party-mocks/README.md)
