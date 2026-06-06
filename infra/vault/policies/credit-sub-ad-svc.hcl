# credit-sub-ad-svc 最小权限策略
# 职责：IAP 校验、广告联盟 Server 回调 Secret、穿山甲/优量汇/AdMob

path "secret/data/dev/cn/credit-sub-ad/*" {
  capabilities = ["read"]
}
path "secret/data/dev/os/credit-sub-ad/*" {
  capabilities = ["read"]
}
path "secret/data/staging/cn/credit-sub-ad/*" {
  capabilities = ["read"]
}
path "secret/data/staging/os/credit-sub-ad/*" {
  capabilities = ["read"]
}

# Apple IAP（App Store Connect API / 共享密钥）
path "secret/data/prod-cn/cn/credit-sub-ad/apple-iap" {
  capabilities = ["read"]
}
path "secret/data/prod-os/os/credit-sub-ad/apple-iap" {
  capabilities = ["read"]
}

# 国内广告联盟 Server 验签
path "secret/data/prod-cn/cn/credit-sub-ad/pangle" {
  capabilities = ["read"]
}
path "secret/data/prod-cn/cn/credit-sub-ad/gdt" {
  capabilities = ["read"]
}

# 海外 AdMob SSV
path "secret/data/prod-os/os/credit-sub-ad/admob" {
  capabilities = ["read"]
}

path "secret/data/prod-cn/cn/shared/postgres-credit" {
  capabilities = ["read"]
}
path "secret/data/prod-cn/cn/shared/redis-credit" {
  capabilities = ["read"]
}
