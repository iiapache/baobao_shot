# 网关路由模板
#
# ApisixRoute CRD — 上游指向微服务 ClusterIP。
# 部署前按环境修改 hosts 与 namespace；域名映射见 ../domains/mapping.yaml
#
# kubectl apply -f infra/gateway/routes/ -n dev

## 路由清单（T1.12）

| 文件 | 上游 | 说明 |
| --- | --- | --- |
| `hello-api.yaml` | hello | T0.6 健康检查占位 |
| `hello-ws.yaml` | hello | WebSocket 占位 |
| `auth-family-api.yaml` | auth-family-svc | CN：JWT forward-auth + 公开 auth + 限流 |
| `auth-family-api-os.yaml` | auth-family-svc | OS：同上 |
| `staging-api-health.yaml` | auth-family-svc | ENV-03：`/health` → staging-api-* |
| `staging-auth-family-api.yaml` | auth-family-svc | ENV-03：staging auth 路由 |

JWT 鉴权采用 `forward-auth` → `auth-family-svc /internal/verify`（HS256 + Redis 黑名单，与 T1.3 一致）。

限流规则见 [../docs/rate-limits.md](../docs/rate-limits.md)。
