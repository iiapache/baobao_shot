# Baobao Kubernetes 基础设施

双集群 K8s 部署模板：**阿里云 ACK（中国）** + **AWS EKS（新加坡）**。

对应设计文档 [design-backend.md §2](../../docs/design-backend.md) 与开发计划 T0.3。

## 目录结构

```
infra/k8s/
├── README.md
├── namespaces/           # 四个共享命名空间
│   ├── namespaces.yaml   # kubectl apply 用
│   └── values.yaml       # Helm/ArgoCD 参考
├── charts/
│   ├── common/           # library chart：labels / annotations / naming
│   ├── hello/            # 最小 hello-world 服务
│   ├── microservice/     # Go 微服务通用 chart（ENV-03）
│   ├── baobao-staging/   # staging umbrella chart（ENV-03）
│   └── third-party-mocks/ # staging 三方 WireMock（ENV-06）
├── clusters/
│   ├── ack-cn/           # 阿里云 ACK 中国 cluster values
│   └── eks-os/           # AWS EKS 新加坡 cluster values
└── argocd/
    └── applications/     # ArgoCD Application 模板
```

## 命名空间

| 命名空间 | 用途 | 主要集群 |
| --- | --- | --- |
| `dev` | 开发联调 | ack-cn、eks-os |
| `staging` | 预发验证 | ack-cn、eks-os |
| `prod-cn` | 中国区生产 | ack-cn |
| `prod-os` | 海外区生产 | eks-os |

### 创建命名空间

```bash
kubectl apply -f infra/k8s/namespaces/namespaces.yaml
kubectl get ns -l app.kubernetes.io/part-of=baobao
```

预期输出包含：`dev`、`staging`、`prod-cn`、`prod-os`。

## Helm Chart 说明

### charts/common（library）

可复用模板定义：

- `baobao.name` / `baobao.fullname` — 资源命名
- `baobao.labels` — 标准 labels（含 `baobao.io/cluster`、`baobao.io/region`、`baobao.io/environment`）
- `baobao.selectorLabels` — Deployment/Service 选择器
- `baobao.annotations` — 通用 annotations

### charts/hello（application）

最小可部署服务，包含：

| 资源 | 说明 |
| --- | --- |
| Deployment | `ealen/echo-server`，HTTP 回显 |
| Service | ClusterIP :80 |
| Ingress | 占位，默认 host `hello.local`，class `nginx` |

依赖 `common` library chart，通过 `global.*` 与 `commonLabels`/`commonAnnotations` 注入集群/环境元数据。

## 部署步骤（生产集群）

### 1. 准备集群上下文

```bash
# ACK 中国
kubectl config use-context ack-cn

# EKS 新加坡
kubectl config use-context eks-os
```

### 2. 创建命名空间

```bash
kubectl apply -f infra/k8s/namespaces/namespaces.yaml
```

### 3. 安装 Ingress Controller

ACK/EKS 按云厂商文档安装 nginx-ingress 或 ALB Ingress Controller。hello chart 默认 `ingress.className: nginx`。

### 4. 部署 hello 服务

```bash
cd infra/k8s/charts/hello
helm dependency update

# ACK dev 示例
helm upgrade --install hello . \
  -n dev \
  -f ../../clusters/ack-cn/cluster-values.yaml \
  -f ../../clusters/ack-cn/dev-hello-values.yaml

# EKS staging 示例
helm upgrade --install hello . \
  -n staging \
  -f ../../clusters/eks-os/cluster-values.yaml \
  -f ../../clusters/eks-os/staging-hello-values.yaml
```

### 5. ArgoCD 持续部署

1. 在 ArgoCD 中注册 `ack-cn`、`eks-os` 两个 cluster secret。
2. 将 `argocd/applications/*.yaml` 中 `spec.source.repoURL` 替换为实际 Git 仓库地址。
3. 应用 Application：

```bash
kubectl apply -f infra/k8s/argocd/applications/hello-dev.yaml
kubectl apply -f infra/k8s/argocd/applications/hello-staging.yaml
```

### 6. CI → 镜像 → ArgoCD（T0.2）

GitLab CI 构建镜像并 push 到容器仓库，ArgoCD 监听 Git 中 Helm values 变更完成部署。完整流程见 [infra/ci/README.md](../ci/README.md)。

蓝绿 / ApplicationSet 模板见 [infra/argocd/README.md](../argocd/README.md)。

## 本地验证（kind / minikube）

以下步骤可在本机验证 chart 渲染与网关访问，**无需真实云集群凭据**。

### 前置条件

- Docker
- [kind](https://kind.sigs.k8s.io/) 或 [minikube](https://minikube.sigs.k8s.io/)
- kubectl、helm ≥ 3.8

### 方案 A：kind

```bash
# 1. 创建集群
kind create cluster --name baobao-local

# 2. 安装 ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# 3. 创建命名空间
kubectl apply -f infra/k8s/namespaces/namespaces.yaml

# 4. 部署 hello（dev 命名空间）
cd infra/k8s/charts/hello
helm dependency update
helm upgrade --install hello . \
  -n dev \
  --set global.cluster=local \
  --set global.region=cn \
  --set global.environment=dev \
  --set ingress.hosts[0].host=hello.local

# 5. 验证 Pod 与 Service
kubectl get pods,svc,ingress -n dev -l app.kubernetes.io/name=hello

# 6. 通过 Ingress 访问（kind 需 port-forward 或 /etc/hosts + 节点 IP）
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 &
curl -H "Host: hello.local" http://127.0.0.1:8080/
# 预期：HTTP 200，echo-server 返回 JSON/HTML 响应
```

### 方案 B：minikube

```bash
minikube start
minikube addons enable ingress

kubectl apply -f infra/k8s/namespaces/namespaces.yaml

cd infra/k8s/charts/hello
helm dependency update
helm upgrade --install hello . \
  -n dev \
  --set global.cluster=local \
  --set ingress.hosts[0].host=hello.local

# 获取 minikube IP 并写入 /etc/hosts：hello.local -> <minikube ip>
minikube ip
curl http://hello.local/
```

### Chart 静态校验（无需集群）

```bash
cd infra/k8s/charts/hello
helm dependency update
helm lint .
helm template hello . -n dev \
  -f ../../clusters/ack-cn/cluster-values.yaml \
  -f ../../clusters/ack-cn/dev-hello-values.yaml \
  | kubectl apply --dry-run=client -f -
```

## 验收自检清单

| 项 | 命令 / 检查 | 预期 |
| --- | --- | --- |
| 命名空间 | `kubectl get ns dev staging prod-cn prod-os` | 四个 NS 存在且 labels 正确 |
| Chart 渲染 | `helm template hello . -n dev -f ...` | Deployment/Service/Ingress YAML 无错误 |
| Pod 就绪 | `kubectl get pods -n dev` | `READY 1/1` |
| 网关访问 | `curl -H "Host: hello.local" http://<ingress>/` | HTTP 200 |
| 双集群 values | 对比 `clusters/ack-cn/` 与 `clusters/eks-os/` | cluster/region 字段区分 CN/OS |
| 无凭据泄露 | `grep -r "password\|secret\|token" infra/k8s/` | 仅占位符，无真实密钥 |

## 安全说明

- **禁止**将 kubeconfig、云账号 AK/SK、TLS 私钥提交到仓库。
- ArgoCD `repoURL`、ECR 账号 ID、域名均为 `example.com` / 占位符，部署前替换。
- 生产 Secret 通过 Vault / Sealed Secrets 管理（见 T0.7）。

## 网关集成（T0.6）

hello 等服务流量改由 APISIX 网关入口，关闭 chart 内 nginx Ingress 后应用 `infra/gateway/routes/`。  
完整部署顺序、TLS 1.3 / HTTP/2 验收见 [infra/gateway/README.md](../gateway/README.md)。

## Staging 三方 Mock（ENV-06）

```bash
./infra/staging/scripts/sync-mock-mappings.sh
helm upgrade --install third-party-mocks infra/k8s/charts/third-party-mocks \
  -n staging -f infra/k8s/clusters/ack-cn/staging-third-party-mocks-values.yaml
tests/staging/verify-outbound.sh --k8s -n staging
```

Outbound 注入 values：`infra/staging/values/` · 映射表：`infra/staging/outbound-mapping.yaml`

## Staging 微服务（ENV-03）

```bash
./infra/staging/scripts/deploy-staging.sh --cluster ack-cn
tests/staging/smoke-staging.sh --cluster ack-cn --resolve <APISIX-LB-IP>
```

Umbrella chart：`infra/k8s/charts/baobao-staging/` · ArgoCD：`infra/k8s/argocd/applications/baobao-staging-*.yaml`

## 后续任务

- T0.4–T0.5：数据库、Kafka、OSS 独立 chart
