# 平台可观测性 — Sentry DSN、Bugly 服务端（如有）
# 通常由各服务 sidecar 或 init 容器读取；也可合并到各服务策略

path "secret/data/dev/global/platform/*" {
  capabilities = ["read"]
}
path "secret/data/staging/global/platform/*" {
  capabilities = ["read"]
}

path "secret/data/prod-cn/global/platform/sentry" {
  capabilities = ["read"]
}
path "secret/data/prod-os/global/platform/sentry" {
  capabilities = ["read"]
}

# Bugly 主要为端侧 SDK；服务端符号化/upload 如有则读此路径
path "secret/data/prod-cn/global/platform/bugly" {
  capabilities = ["read"]
}
