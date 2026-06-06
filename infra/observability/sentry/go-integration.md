# Go Sentry 接入速查

完整说明见 [README.md](./README.md)。

## 环境变量

| 变量 | 示例 | 说明 |
| --- | --- | --- |
| `SENTRY_DSN` | `https://...@sentry.io/...` | Vault 注入，空则禁用 |
| `SENTRY_RELEASE` | `hello@abc1234` | CI 注入 git sha |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `otel-collector.observability.svc:4317` | 与 template tracing 一致 |
| `ENVIRONMENT` | `dev` | Sentry environment tag |

## K8s Deployment 片段

```yaml
env:
  - name: SENTRY_DSN
    valueFrom:
      secretKeyRef:
        name: baobao-sentry
        key: backend-dsn
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: otel-collector.observability.svc:4317
  - name: ENVIRONMENT
    value: dev
  - name: SERVICE_NAME
    value: hello
```

## 依赖

```
github.com/getsentry/sentry-go v0.28.1
github.com/getsentry/sentry-go/http
```

## Smoke test

```bash
# 需服务实现 GET /debug/sentry-test（仅 dev）
curl http://hello.dev.svc:8080/debug/sentry-test
```

Sentry → Issues → 搜索 `T0.8 smoke test`。
