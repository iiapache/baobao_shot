# auth-family-svc 最小权限策略
# 职责：Apple 登录、手机号短信、微信 OAuth（V1.1）、百度网盘 OAuth 客户端凭据、JWT 签名

# 开发 / 预发（按 region 隔离）
path "secret/data/dev/cn/auth-family/*" {
  capabilities = ["read"]
}
path "secret/data/dev/os/auth-family/*" {
  capabilities = ["read"]
}
path "secret/data/staging/cn/auth-family/*" {
  capabilities = ["read"]
}
path "secret/data/staging/os/auth-family/*" {
  capabilities = ["read"]
}

# 产线 — 绑定 Pod 所在 region，此处示例为 prod-cn
path "secret/data/prod-cn/cn/auth-family/*" {
  capabilities = ["read"]
}

# 数据库 / Redis（T0.7 共用路径）
path "secret/data/prod-cn/cn/shared/postgres-auth-family" {
  capabilities = ["read"]
}
path "secret/data/prod-cn/cn/shared/redis-auth-family" {
  capabilities = ["read"]
}

# JWT 签名密钥（轮换时需 patch 权限，生产建议独立 break-glass 角色）
path "secret/data/prod-cn/cn/auth-family/jwt-signing" {
  capabilities = ["read"]
}

# 明确拒绝跨区产线
path "secret/data/prod-os/*" {
  capabilities = ["deny"]
}
