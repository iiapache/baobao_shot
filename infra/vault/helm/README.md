# Vault Server Helm 部署

> 对应 T0.7。Chart 来源：[hashicorp/vault](https://github.com/hashicorp/vault-helm)（`helm repo add hashicorp https://helm.releases.hashicorp.com`）。

## 环境对照

| 环境 | Values 文件 | 模式 | 命名空间建议 |
| --- | --- | --- | --- |
| dev | `values-dev.yaml` | 单节点 dev 模式（**禁止用于 prod**） | `vault-dev` |
| staging | `values-staging.yaml` | HA Raft 3 副本 | `vault-staging` |

## 部署

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# dev（本地 / 开发集群）
helm upgrade --install vault hashicorp/vault \
  -n vault-dev --create-namespace \
  -f infra/vault/helm/values-dev.yaml

# staging（预发 HA）
helm upgrade --install vault hashicorp/vault \
  -n vault-staging --create-namespace \
  -f infra/vault/helm/values-staging.yaml
```

## 初始化（staging / prod 必做）

dev 模式自动 unseal；staging 需手动 init：

```bash
kubectl exec -n vault-staging vault-0 -- vault operator init -key-shares=5 -key-threshold=3
# 保存 unseal keys 与 root token 至 break-glass 保险库，勿入 Git

kubectl exec -n vault-staging vault-0 -- vault secrets enable -path=secret kv-v2
kubectl exec -n vault-staging vault-0 -- vault auth enable kubernetes
```

Kubernetes Auth 与各服务 `policies/*.hcl` 绑定见 [`../README.md`](../README.md) §3.2。

## 与 infra/data 对齐

PostgreSQL Bitnami Chart 使用 K8s Secret `baobao-postgresql`（keys: `postgres-password`、`password`）。  
应用侧 DB 凭据 Vault 路径：

```text
secret/data/{env}/{region}/shared/postgres-{service}
```

示例：`secret/data/dev/cn/shared/postgres-auth-family` → 字段见 [`../secrets-template/shared-postgres.env.example`](../secrets-template/shared-postgres.env.example)。
