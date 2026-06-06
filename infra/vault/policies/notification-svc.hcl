# notification-svc 最小权限策略
# 职责：APNs HTTP/2（Key 来自 Apple Developer）

path "secret/data/dev/cn/notification/*" {
  capabilities = ["read"]
}
path "secret/data/dev/os/notification/*" {
  capabilities = ["read"]
}
path "secret/data/staging/cn/notification/*" {
  capabilities = ["read"]
}
path "secret/data/staging/os/notification/*" {
  capabilities = ["read"]
}

path "secret/data/prod-cn/cn/notification/apns" {
  capabilities = ["read"]
}
path "secret/data/prod-os/os/notification/apns" {
  capabilities = ["read"]
}

path "secret/data/prod-cn/cn/shared/postgres-notification" {
  capabilities = ["read"]
}
path "secret/data/prod-cn/cn/shared/redis-notification" {
  capabilities = ["read"]
}
