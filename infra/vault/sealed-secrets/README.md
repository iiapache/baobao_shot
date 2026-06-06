# Sealed Secrets

用于 **Git 安全存储** K8s Secret 密文（bootstrap 或 Vault 不可用时的降级路径）。  
生产首选 Vault Agent Injector / External Secrets Operator；SealedSecret 适用于：

- PostgreSQL Helm `existingSecret: baobao-postgresql` 的初始 bootstrap
- CI/CD 无法直连 Vault 时的只读静态 Secret
- 非应用运行时 Secret（如 `vault-tls`）

## 生成加密 Secret

```bash
# 1. 安装 kubeseal（与集群 Sealed Secrets Controller 版本匹配）
brew install kubeseal

# 2. 从明文模板生成 SealedSecret（勿提交明文）
kubectl create secret generic baobao-postgresql \
  -n dev \
  --from-literal=postgres-password='REPLACE_ME' \
  --from-literal=password='REPLACE_ME' \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system \
    --format yaml > infra/vault/sealed-secrets/baobao-postgresql-dev.yaml
```

## 与 Vault 路径对齐

| SealedSecret 名称 | 命名空间 | 对应 Vault path |
| --- | --- | --- |
| `baobao-postgresql` | `dev` | `secret/data/dev/cn/shared/postgres-auth-family` |
| `baobao-postgresql` | `staging` | `secret/data/staging/cn/shared/postgres-auth-family` |

字段 `postgres-password` / `password` 与 [`infra/data/postgresql/values.yaml`](../../data/postgresql/values.yaml) 中 `secretKeys` 一致。

## 仓库内文件

| 文件 | 说明 |
| --- | --- |
| `baobao-postgresql-dev.yaml` | **加密占位**；部署前须用 kubeseal 重新生成 |
