# Baobao 数据层基础设施（T0.4）

PostgreSQL 15、MongoDB 6、Redis 7 双区独立部署模板，对应 [design-backend.md §4](../../docs/design-backend.md) 与开发计划 T0.4。

## 设计原则

| 原则 | 说明 |
| --- | --- |
| 双区独立 | **ack-cn**（阿里云 ACK 中国）与 **eks-os**（AWS EKS 新加坡）各自维护独立实例，**不跨区复制** |
| 环境分级 | `dev` / `staging` 单节点简化；`prod-cn` / `prod-os` 生产高可用 |
| 无真实凭据 | 密码、连接串均使用环境变量占位，生产 Secret 由 Vault 注入（T0.7） |
| Chart 来源 | 基于 [Bitnami Helm Charts](https://github.com/bitnami/charts) 的 values 覆盖，与 `infra/k8s` 目录结构一致 |

## 目录结构

```text
infra/data/
├── README.md                 # 本文件
├── docker-compose.dev.yml    # 本地 PG + Mongo + Redis 一键启动
├── .env.example              # 本地环境变量占位
├── postgresql/               # PostgreSQL 15
├── mongodb/                  # MongoDB 6
├── redis/                    # Redis 7
├── scripts/
│   └── connectivity-test.sh  # 端到端连通性自测
├── backup/
│   └── BACKUP_POLICY.md      # 每日备份策略
└── monitoring/
    └── slow-query.md         # 慢查询监控接入 Prometheus
```

## 容量参考（design-backend §12.2）

| 组件 | 生产规格 | 存储 |
| --- | --- | --- |
| PostgreSQL 15 | 主备（prod）/ 单节点（dev/staging） | 100 GB |
| MongoDB 6 | 副本集 3 节点（prod）/ 单节点（dev/staging） | 500 GB |
| Redis 7 | 主从 + Sentinel（prod）/ 单节点（dev/staging） | 32 GB |

---

## 本地开发（docker-compose）

```bash
cd infra/data
cp .env.example .env
# 编辑 .env 填入占位密码（勿使用生产凭据）
docker compose -f docker-compose.dev.yml up -d
./scripts/connectivity-test.sh
```

默认端口：

| 服务 | 端口 | 说明 |
| --- | --- | --- |
| PostgreSQL | 5432 | 库名 `baobao` |
| MongoDB | 27017 | 库名 `baobao` |
| Redis | 6379 | DB 0 |

---

## K8s 部署概览

### 命名空间

与 [infra/k8s/namespaces](../k8s/namespaces/namespaces.yaml) 一致：

| 命名空间 | 集群 | 数据层模式 |
| --- | --- | --- |
| `dev` | ack-cn、eks-os | 单节点 |
| `staging` | ack-cn、eks-os | 单节点 |
| `prod-cn` | ack-cn | 高可用 |
| `prod-os` | eks-os | 高可用 |

### 部署顺序

每个集群、每个命名空间独立执行：

```bash
# 1. 切换集群上下文
kubectl config use-context ack-cn   # 或 eks-os

# 2. 创建命名空间（若尚未创建）
kubectl apply -f infra/k8s/namespaces/namespaces.yaml

# 3. 添加 Bitnami repo（首次）
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 4. 创建 Secret（占位示例，生产走 Vault）
kubectl create secret generic baobao-postgresql \
  -n dev \
  --from-literal=postgres-password="${POSTGRES_PASSWORD}" \
  --from-literal=password="${POSTGRES_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -
```

### PostgreSQL 15

```bash
# dev 单节点（ACK 中国示例）
helm upgrade --install postgresql bitnami/postgresql \
  -n dev \
  -f infra/data/postgresql/values.yaml \
  -f infra/data/postgresql/values-single.yaml \
  -f infra/k8s/clusters/ack-cn/cluster-values.yaml \
  -f infra/data/postgresql/clusters/ack-cn/dev-values.yaml

# prod-cn 主备
helm upgrade --install postgresql bitnami/postgresql \
  -n prod-cn \
  -f infra/data/postgresql/values.yaml \
  -f infra/data/postgresql/values-ha.yaml \
  -f infra/k8s/clusters/ack-cn/cluster-values.yaml \
  -f infra/data/postgresql/clusters/ack-cn/prod-values.yaml
```

或使用简化 StatefulSet（无需 Helm）：

```bash
kubectl apply -f infra/data/postgresql/statefulset-dev.yaml -n dev
```

### MongoDB 6

```bash
helm upgrade --install mongodb bitnami/mongodb \
  -n dev \
  -f infra/data/mongodb/values.yaml \
  -f infra/data/mongodb/values-single.yaml \
  -f infra/k8s/clusters/ack-cn/cluster-values.yaml \
  -f infra/data/mongodb/clusters/ack-cn/dev-values.yaml
```

### Redis 7

```bash
helm upgrade --install redis bitnami/redis \
  -n dev \
  -f infra/data/redis/values.yaml \
  -f infra/data/redis/values-single.yaml \
  -f infra/k8s/clusters/ack-cn/cluster-values.yaml \
  -f infra/data/redis/clusters/ack-cn/dev-values.yaml
```

### EKS 海外区（eks-os）

将上述命令中的 `ack-cn` 替换为 `eks-os`，命名空间 `prod-cn` 替换为 `prod-os`：

```bash
kubectl config use-context eks-os

helm upgrade --install postgresql bitnami/postgresql \
  -n prod-os \
  -f infra/data/postgresql/values.yaml \
  -f infra/data/postgresql/values-ha.yaml \
  -f infra/k8s/clusters/eks-os/cluster-values.yaml \
  -f infra/data/postgresql/clusters/eks-os/prod-values.yaml
```

---

## 服务连接串（占位）

应用通过 Vault 或 K8s Secret 注入，**禁止**硬编码到代码仓库：

```bash
# PostgreSQL
POSTGRES_HOST=postgresql.dev.svc.cluster.local
POSTGRES_PORT=5432
POSTGRES_DB=baobao
POSTGRES_USER=baobao
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# MongoDB
MONGODB_URI=mongodb://${MONGODB_USER}:${MONGODB_PASSWORD}@mongodb.dev.svc.cluster.local:27017/baobao?authSource=admin

# Redis
REDIS_HOST=redis-master.dev.svc.cluster.local
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}
```

---

## 运维文档

- [backup/BACKUP_POLICY.md](./backup/BACKUP_POLICY.md) — 每日备份策略
- [monitoring/slow-query.md](./monitoring/slow-query.md) — 慢查询监控接入 Prometheus

---

## 验收自检

| 项 | 命令 / 检查 | 预期 |
| --- | --- | --- |
| 本地 compose 启动 | `docker compose -f docker-compose.dev.yml up -d` | 三个容器 Running |
| 连通性自测 | `./scripts/connectivity-test.sh` | 全部 PASS |
| Helm values 渲染 | `helm template postgresql bitnami/postgresql -f postgresql/values.yaml -f postgresql/values-single.yaml` | YAML 无错误 |
| 双区 values | 对比 `postgresql/clusters/ack-cn/` 与 `eks-os/` | cluster/region 字段区分 |
| 慢日志配置 | 检查 postgresql values 中 `log_min_duration_statement` | 已配置 500ms |
| 备份文档 | 阅读 `backup/BACKUP_POLICY.md` | 含 PG/Mongo/Redis 每日策略 |
| 无凭据泄露 | `grep -rE "password.*=.*[^R][^E][^P]" infra/data/ \| grep -v example` | 无真实密码 |

---

## 安全说明

- **禁止**将真实密码、连接串提交到 Git。
- 生产 Secret 通过 Vault / Sealed Secrets 管理（见 [infra/vault](../vault/README.md)）。
- ack-cn 与 eks-os 数据完全隔离，满足跨境合规要求（design-backend §2）。

## 后续任务

- T0.7：Vault 注入 DB 密码，替换 K8s 手动 Secret
- T0.8：Prometheus 抓取 postgres_exporter / mongodb_exporter / redis_exporter（见 slow-query.md）
