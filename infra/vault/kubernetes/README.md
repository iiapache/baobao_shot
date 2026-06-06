# External Secrets Operator — 从 Vault 同步 Secret 至 K8s
#
# 方案 A: Vault Agent Injector — 文件注入 /vault/secrets/*.env（见 vault-agent-injector-example.yaml）
# 方案 B: ESO — 同步为 K8s Secret，供 Helm existingSecret 或 envFrom 使用
#
# PostgreSQL Bitnami Chart 使用 Secret `baobao-postgresql`，keys 见 infra/data/postgresql/values.yaml
