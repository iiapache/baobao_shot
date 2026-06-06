# iap-callback-svc 最小权限策略
# 职责：接收 Apple Server Notifications v2，验证 JWS

path "secret/data/dev/cn/iap-callback/*" {
  capabilities = ["read"]
}
path "secret/data/dev/os/iap-callback/*" {
  capabilities = ["read"]
}
path "secret/data/staging/cn/iap-callback/*" {
  capabilities = ["read"]
}
path "secret/data/staging/os/iap-callback/*" {
  capabilities = ["read"]
}

path "secret/data/prod-cn/cn/iap-callback/apple-asn" {
  capabilities = ["read"]
}
path "secret/data/prod-os/os/iap-callback/apple-asn" {
  capabilities = ["read"]
}

path "secret/data/prod-cn/cn/shared/redis-iap-callback" {
  capabilities = ["read"]
}
