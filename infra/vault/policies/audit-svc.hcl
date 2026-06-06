# audit-svc 最小权限策略
# 职责：阿里云内容安全（CN）、海外审核厂商（OS，V1 可后续扩展）

path "secret/data/dev/cn/audit/*" {
  capabilities = ["read"]
}
path "secret/data/dev/os/audit/*" {
  capabilities = ["read"]
}
path "secret/data/staging/cn/audit/*" {
  capabilities = ["read"]
}
path "secret/data/staging/os/audit/*" {
  capabilities = ["read"]
}

path "secret/data/prod-cn/cn/audit/aliyun-green" {
  capabilities = ["read"]
}

# OS 区（AWS Rekognition / Cloudflare — 按实际上线扩展）
path "secret/data/prod-os/os/audit/aws-rekognition" {
  capabilities = ["read"]
}
path "secret/data/prod-os/os/audit/cloudflare" {
  capabilities = ["read"]
}

path "secret/data/prod-cn/cn/shared/postgres-audit" {
  capabilities = ["read"]
}
path "secret/data/prod-cn/cn/shared/redis-audit" {
  capabilities = ["read"]
}
