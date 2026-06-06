# GitLab CI 最小权限策略 — 仅读 dev / staging，禁止 prod
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
