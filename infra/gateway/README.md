# Baobao API 网关（T0.6）

> Apache APISIX 网关：TLS 终止、HTTP/2、双区域域名（`api-cn` / `api-os` / `ws-cn` / `ws-os`）。  
> 对应 [design-backend.md §2/§9](../../docs/design-backend.md)、[design.md §7.2](../../docs/design.md)、开发计划 T0.6。

## 目录结构

```text
infra/gateway/
├── README.md                 # 本文件
├── charts/baobao-gateway/    # APISIX Helm 封装 + values
├── routes/                   # ApisixRoute 路由模板（hello 上游示例）
├── tls/                      # cert-manager ClusterIssuer + ApisixTls
├── domains/                  # 域名映射表
└── scripts/health-check.sh   # curl/openssl 验收脚本
```

## 网关选型

| 维度 | 选型 |
| --- | --- |
| 产品 | **Apache APISIX**（design §2：Kong 或 APISIX） |
| 部署 | Helm（官方 chart 作 dependency） |
| IngressClass | `apisix` |
| TLS | 网关终止，cert-manager 签发 |
| 协议 | TLS 1.3 强制 + HTTP/2 |

## 与 infra/k8s 集成

### 架构关系

```text
Internet
    │
    ▼
[APISIX Gateway LB :443]     ← infra/gateway（T0.6）
    │  TLS 1.3 + HTTP/2
    ▼
[ApisixRoute]                ← infra/gateway/routes/
    │
    ▼
[hello / 微服务 ClusterIP]   ← infra/k8s/charts/hello（T0.3）
```

### 命名空间

| 资源 | 命名空间 | 说明 |
| --- | --- | --- |
| APISIX gateway + etcd + ingress-controller | `gateway` | 本 chart 安装目标 |
| hello 示例上游 | `dev` / `staging` / `prod-cn` / `prod-os` | 与 [k8s/namespaces](../k8s/namespaces/namespaces.yaml) 一致 |
| cert-manager Certificate / ApisixTls | `gateway` | TLS Secret 与网关同 NS |

### 部署顺序（ACK dev 示例）

```bash
# 1. 命名空间（若 T0.3 未执行）
kubectl apply -f infra/k8s/namespaces/namespaces.yaml
kubectl create namespace gateway --dry-run=client -o yaml | kubectl apply -f -

# 2. 上游 hello 服务（T0.3）
cd infra/k8s/charts/hello && helm dependency update
helm upgrade --install hello . -n dev \
  -f ../../clusters/ack-cn/cluster-values.yaml \
  -f ../../clusters/ack-cn/dev-hello-values.yaml \
  --set ingress.enabled=false   # 流量改走 APISIX，关闭 nginx Ingress

# 3. 安装 APISIX 网关
helm repo add apisix https://charts.apiseven.com
cd infra/gateway/charts/baobao-gateway && helm dependency update
helm upgrade --install gateway . -n gateway --create-namespace \
  -f values.yaml \
  -f values-ack-cn.yaml

# 4. TLS（cert-manager 已安装前提下）
kubectl apply -f infra/gateway/tls/cluster-issuer.yaml

# 5. 路由
kubectl apply -f infra/gateway/routes/hello-api.yaml -n dev
kubectl apply -f infra/gateway/routes/hello-ws.yaml -n dev
kubectl apply -f infra/gateway/routes/auth-family-api.yaml -n dev   # T1.12

# 6. 验收
chmod +x infra/gateway/scripts/health-check.sh
./infra/gateway/scripts/health-check.sh --check-tls --check-http2 \
  --host dev-api-cn.example.com --resolve <APISIX-LB-IP>
```

### hello Ingress 迁移说明

T0.3 hello chart 默认 `ingress.className: nginx`。启用 APISIX 后：

1. 部署网关 chart 到 `gateway` 命名空间。
2. hello 设置 `ingress.enabled: false`，避免 nginx 与 APISIX 双入口。
3. 通过 `routes/hello-api.yaml` 将 `dev-api-cn.example.com` 指向 hello Service。

生产微服务接入时，复制 `routes/hello-api.yaml` 模式，将 `serviceName` 改为 `auth-family-svc` 等，path 按 [design-api.md](../../docs/design-api.md) `/v1/*` 划分。

### 双集群 values 对照

| 文件 | 集群 | API 域名 | WS 域名 |
| --- | --- | --- | --- |
| `values-ack-cn.yaml` | ack-cn | dev-api-cn.example.com | dev-ws-cn.example.com |
| `values-eks-os.yaml` | eks-os | dev-api-os.example.com | dev-ws-os.example.com |

完整环境/生产域名见 [domains/mapping.yaml](./domains/mapping.yaml)。

### ArgoCD 集成（可选）

可新增 Application 指向 `infra/gateway/charts/baobao-gateway`，与 [infra/k8s/argocd](../k8s/argocd/) hello Application 并列；路由 manifest 可作为独立 Application 或 Kustomize 层。

## TLS 与 HTTP/2

配置细节与验证命令见 [tls/README.md](./tls/README.md)。

要点：

- `apisix.set_config.apisix.ssl.ssl_protocols: TLSv1.3`
- `apisix.enableHttp2: true`
- cert-manager `Certificate` + `ApisixTls` 绑定 SNI

## 本地 kind 快速验证

```bash
kind create cluster --name baobao-gw
kubectl apply -f infra/k8s/namespaces/namespaces.yaml
kubectl create namespace gateway

# 部署 hello（无 Ingress）
cd infra/k8s/charts/hello && helm dependency update
helm upgrade --install hello . -n dev \
  --set ingress.enabled=false \
  --set global.cluster=local --set global.region=cn

# 部署网关（NodePort/端口转发替代 LB）
cd ../../gateway/charts/baobao-gateway
helm repo add apisix https://charts.apiseven.com && helm dependency update
helm upgrade --install gateway . -n gateway \
  -f values.yaml --set apisix.gateway.type=NodePort

kubectl apply -f ../../routes/ -n dev
kubectl port-forward -n gateway svc/gateway-apisix-gateway 8443:443 &

INSECURE=1 ./../../scripts/health-check.sh \
  --host dev-api-cn.example.com --resolve 127.0.0.1 --insecure
```

## 验收自检清单

| 项 | 命令 / 检查 | 预期 |
| --- | --- | --- |
| Chart 渲染 | `cd charts/baobao-gateway && helm dependency update && helm template gateway . -f values-ack-cn.yaml` | 无 YAML 错误 |
| 网关 Pod | `kubectl get pods -n gateway` | APISIX / etcd Ready |
| 健康 200 | `./scripts/health-check.sh --host <api-host> --resolve <LB-IP>` | `/health` → 200 |
| TLS 1.3 | `./scripts/health-check.sh --check-tls ...` | 仅 TLSv1.3 成功 |
| HTTP/2 | `./scripts/health-check.sh --check-http2 ...` | `HTTP/2 200` |
| 域名映射 | 对照 `domains/mapping.yaml` | api-cn/os、ws-cn/os 四套齐全 |
| JWT 401 | `./scripts/health-check.sh --check-auth ...` | 无 Token → 401 `AUTH_TOKEN_EXPIRED` |
| refresh 直通 | `--check-auth` | refresh 返回 400 而非 401 |
| 限流文档 | `docs/rate-limits.md` | design-api §2.7 已映射 |
| 无凭据泄露 | `grep -rE 'AKIA|BEGIN (RSA\|EC) PRIVATE' infra/gateway/` | 无真实密钥 |
| k8s 集成 | hello `ingress.enabled=false` + ApisixRoute | 单入口经 APISIX |

## 安全说明

- DNS solver、云 API 凭证通过 External Secrets / Vault 注入（T0.7）。
- 仓库内均为 `example.com` / `babygrowth.app` 占位域名。
- JWT 经 `forward-auth` 委托 `auth-family-svc /internal/verify`（T1.12），不在网关重复实现 HS256。

## JWT 鉴权与限流（T1.12）

| 能力 | 实现 |
| --- | --- |
| JWT 校验 | APISIX `forward-auth` → `auth-family-svc /internal/verify` |
| 401 格式 | 与 design-api §2.5 一致（`code` / `message` / `requestId`） |
| 公开路由 | `POST /v1/auth/apple`、`/phone/code`、`/phone/login`、`/refresh` |
| 受保护路由 | `/v1/account/*`、`/v1/families/*`、`/v1/invitations/*` |
| 限流 | `limit-count` + `serverless-pre-function` 提取手机号，详见 [docs/rate-limits.md](./docs/rate-limits.md) |

### 部署 auth-family 路由

```bash
# auth-family-svc 已部署到 dev 命名空间后
kubectl apply -f infra/gateway/routes/auth-family-api.yaml -n dev
# eks-os:
kubectl apply -f infra/gateway/routes/auth-family-api-os.yaml -n dev

# T1.12 验收
./infra/gateway/scripts/health-check.sh \
  --host dev-api-cn.example.com --resolve <LB-IP> --check-auth
```

### 为何不用 APISIX jwt-auth

auth-family-svc 签发 HS256 JWT，claims 为 `sub`/`typ`/`families` 等业务字段，不含 APISIX `jwt-auth` 要求的 consumer `key`。  
使用 `forward-auth` 可复用服务端 `ValidateAccess`（含 Redis 黑名单），避免网关与服务校验逻辑分叉。

## 后续任务

- T3.x / T4.x / T5.x：ai-dispatch、feed、credit 等微服务 ApisixRoute + userId 维度限流
- T7.11：蓝绿流量灰度（APISIX traffic-split 插件）
