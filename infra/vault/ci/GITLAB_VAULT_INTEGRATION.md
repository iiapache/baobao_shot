# GitLab CI 集成 HashiCorp Vault

> 对应 T0.7；前置 T0.2 CI 已完成。  
> 原则：**CI 仅读 dev/staging**；产线 Key 运行时由 Pod 从 Vault 注入，**不得** bake 进镜像。

---

## 1. 架构

```mermaid
flowchart LR
    GL[GitLab CI Job] -->|JWT / AppRole| V[Vault dev/staging]
    V -->|kv get| Secrets[secret/data/dev|staging/...]
    GL --> Build[build / test]
    Pod[K8s Pod] -->|Kubernetes Auth| V2[Vault]
    V2 --> Runtime[运行时 DB / API Key]
```

| 角色 | Vault Auth | 可读路径 | TTL |
| --- | --- | --- | --- |
| `gitlab-ci-dev` | JWT（GitLab OIDC）或 AppRole | `secret/data/dev/*`、`secret/data/staging/*` | 15m |
| `gitlab-ci-staging-deploy` | AppRole（Protected branch） | `secret/data/staging/*` | 15m |
| 服务 Pod | Kubernetes Auth | 见 `policies/{service}.hcl` | 1h |

---

## 2. Vault 侧配置

### 2.1 创建 CI 策略

```hcl
# infra/vault/policies/gitlab-ci-dev.hcl（需在 Vault 写入）
path "secret/data/dev/*" {
  capabilities = ["read", "list"]
}
path "secret/data/staging/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/dev/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/staging/*" {
  capabilities = ["read", "list"]
}
path "secret/data/prod-cn/*" {
  capabilities = ["deny"]
}
path "secret/data/prod-os/*" {
  capabilities = ["deny"]
}
```

```bash
vault policy write gitlab-ci-dev policies/gitlab-ci-dev.hcl
```

### 2.2 AppRole（推荐 MR / 集成测试）

```bash
vault auth enable -path=approle approle  # 若未启用

vault write auth/approle/role/gitlab-ci-dev \
  token_policies=gitlab-ci-dev \
  token_ttl=15m \
  token_max_ttl=30m \
  secret_id_ttl=0

vault read auth/approle/role/gitlab-ci-dev/role-id
# secret_id 通过 break-glass 流程签发，存入 GitLab Protected Variable VAULT_SECRET_ID
```

### 2.3 GitLab JWT Auth（可选，GitLab 16+）

```bash
vault auth enable -path=jwt jwt

vault write auth/jwt/config \
  jwks_url="https://gitlab.example.com/-/jwks" \
  bound_issuer="gitlab.example.com"

vault write auth/jwt/role/gitlab-ci-dev \
  role_type=jwt \
  bound_audiences="https://vault.dev.internal" \
  user_claim=sub \
  bound_claims='{"project_path":"baobao/baobao"}' \
  token_policies=gitlab-ci-dev \
  token_ttl=15m
```

---

## 3. GitLab CI/CD 变量

在 **Settings → CI/CD → Variables** 配置（全部 **Masked + Protected**）：

| 变量 | 说明 | 环境 |
| --- | --- | --- |
| `VAULT_ADDR` | `https://vault.dev.internal` | dev/staging job |
| `VAULT_ROLE_ID` | AppRole role-id | Protected |
| `VAULT_SECRET_ID` | AppRole secret-id | Protected |
| `VAULT_NAMESPACE` | 留空（OSS Vault）或 enterprise namespace | 可选 |

**禁止**在 Variables 中存放：产线模型 API Key、DB 密码、JWT 签名密钥。

端侧 SDK Key（穿山甲、AdMob 等）走 GitLab Variables，见 [`../../accounts/THIRD_PARTY_ACCOUNTS.md`](../../accounts/THIRD_PARTY_ACCOUNTS.md)。

---

## 4. `.gitlab-ci.yml` 片段

```yaml
.vault_login:
  image:
    name: hashicorp/vault:1.16
    entrypoint: [""]
  before_script:
    - export VAULT_ADDR="${VAULT_ADDR}"
    - |
      export VAULT_TOKEN=$(vault write -field=token auth/approle/login \
        role_id="${VAULT_ROLE_ID}" \
        secret_id="${VAULT_SECRET_ID}")
    - vault token lookup

test:integration:auth-family:
  stage: test
  extends: .vault_login
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes:
        - services/auth-family/**/*
  script:
    # 读取 DB 密码（与 infra/data postgresql 路径对齐）
    - vault kv get -format=json secret/dev/cn/shared/postgres-auth-family > /tmp/pg.json
    - export POSTGRES_PASSWORD=$(jq -r '.data.data.password' /tmp/pg.json)
    - export POSTGRES_HOST=$(jq -r '.data.data.host' /tmp/pg.json)
    - make -C services/auth-family test-integration
  after_script:
    - unset VAULT_TOKEN POSTGRES_PASSWORD
```

### 4.1 读取模型 API Key（集成测试）

```bash
# ai-dispatch staging 冒烟 — 仅 staging 路径
vault kv get -format=json secret/staging/cn/ai-dispatch/bytedance
vault kv get -format=json secret/staging/os/ai-dispatch/openai   # eks-os job only
```

路径与 [`../secrets-template/`](../secrets-template/) 及 [`../policies/`](../policies/) 一一对应。

---

## 5. 与 K8s 运行时分工

| 场景 | 机制 |
| --- | --- |
| CI 集成测试 | GitLab CI + AppRole/JWT 读 Vault |
| 服务运行时 DB 密码 | Vault Agent Injector 或 ESO → 见 [`../kubernetes/`](../kubernetes/) |
| PostgreSQL Chart Secret | ESO 同步 `baobao-postgresql` 或 SealedSecret bootstrap |
| 密钥轮换 | 见 [`../rotation/SOP.md`](../rotation/SOP.md) |

---

## 6. 安全约束

1. CI job 结束后 `unset VAULT_TOKEN`；禁止 `echo` Token 或 Secret 到日志。
2. `docker build` **不得**使用 `--build-arg` 传入 Vault 凭据。
3. dev Token **403** 访问 `secret/data/prod-cn/*`（策略 deny）。
4. 集成测试使用 **staging** 专用 Key；dev Key 与 prod 物理隔离。
5. Audit log 保留 ≥ 180 天；CI 异常读取触发告警。

---

## 7. 验收自检

| 检查项 | 命令 | 期望 |
| --- | --- | --- |
| CI 策略无 prod 读权限 | `vault policy read gitlab-ci-dev` | 含 `deny` prod-cn/prod-os |
| AppRole 登录 | `vault write auth/approle/login ...` | 返回 token |
| 读 DB 路径 | `vault kv get secret/dev/cn/shared/postgres-auth-family` | 200，含 password 字段 |
| 读模型 Key | `vault kv get secret/staging/cn/ai-dispatch/bytedance` | 200 |
| prod 隔离 | dev CI token 读 prod 路径 | 403 |
| 日志无泄露 | 检查 CI job log | 无 password / api_key 明文 |

---

## 8. 相关文档

- Vault 总览：[`../README.md`](../README.md)
- 密钥轮换：[`../rotation/SOP.md`](../rotation/SOP.md)
- CI 基础设施：[`../../ci/README.md`](../../ci/README.md)
- PostgreSQL Secret 对齐：[`../../data/postgresql/values.yaml`](../../data/postgresql/values.yaml)
