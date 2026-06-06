# caption-svc 最小权限策略
# 职责：智能文案（国内通义千问 Turbo / 海外 GPT-4o-mini）

path "secret/data/dev/cn/caption/*" {
  capabilities = ["read"]
}
path "secret/data/dev/os/caption/*" {
  capabilities = ["read"]
}
path "secret/data/staging/cn/caption/*" {
  capabilities = ["read"]
}
path "secret/data/staging/os/caption/*" {
  capabilities = ["read"]
}

path "secret/data/prod-cn/cn/caption/alibaba-qwen" {
  capabilities = ["read"]
}
path "secret/data/prod-os/os/caption/openai" {
  capabilities = ["read"]
}

path "secret/data/prod-cn/cn/shared/redis-caption" {
  capabilities = ["read"]
}
