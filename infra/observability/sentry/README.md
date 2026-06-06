# Sentry 错误监控接入

> T0.8 验收：Sentry 收到示例异常（Go 服务 + iOS 端各一条）。

## 1. 项目与 DSN

1. 在 [Sentry](https://sentry.io) 创建 Organization `baobao`（或公司已有 Org）。
2. 创建两个 Project：
   - `baobao-backend` — Go 微服务
   - `baobao-ios` — iOS App
3. 从 **Settings → Projects → Client Keys (DSN)** 复制 DSN。
4. 将 DSN 写入 Vault（禁止硬编码进仓库）：

```bash
vault kv put secret/dev/cn/shared/sentry \
  backend_dsn="https://<key>@o<org>.ingest.sentry.io/<backend-project>" \
  ios_dsn="https://<key>@o<org>.ingest.sentry.io/<ios-project>"
```

K8s 部署时通过 External Secrets / Vault Agent 注入为环境变量 `SENTRY_DSN`。

---

## 2. Go 微服务接入

与 `services/_template/go` 并存：OpenTelemetry 负责 tracing/metrics，Sentry 负责 panic 与显式错误上报。

### 2.1 依赖

```bash
go get github.com/getsentry/sentry-go@v0.28.1
```

### 2.2 初始化（`cmd/server/main.go`）

```go
import "github.com/getsentry/sentry-go"

func initSentry(cfg *config.Config) error {
    dsn := os.Getenv("SENTRY_DSN")
    if dsn == "" {
        slog.Info("sentry disabled", "reason", "SENTRY_DSN not set")
        return nil
    }
    return sentry.Init(sentry.ClientOptions{
        Dsn:              dsn,
        Environment:      cfg.Environment,
        Release:          os.Getenv("SENTRY_RELEASE"), // 如 git sha，CI 注入
        TracesSampleRate: 0.1, // dev 可 1.0
        EnableTracing:    true,
    })
}
```

在 `run()` 开头调用 `initSentry`，退出前 `sentry.Flush(2 * time.Second)`。

### 2.3 捕获 panic 与 HTTP 5xx

```go
import sentryhttp "github.com/getsentry/sentry-go/http"

// router 最外层包裹
handler := sentryhttp.New(sentryhttp.Options{Repanic: true}).Handle(rest.NewRouter(cfg))
```

业务错误：

```go
if err != nil {
    sentry.CaptureException(err)
    // ...
}
```

### 2.4 与 OTEL 对齐

| 能力 | 环境变量 | 说明 |
| --- | --- | --- |
| Tracing | `OTEL_EXPORTER_OTLP_ENDPOINT=otel-collector.observability.svc:4317` | 见 `internal/middleware/tracing.go` |
| Sentry | `SENTRY_DSN` | 错误与 panic |
| 环境 | `ENVIRONMENT=dev` | 两者共用 |

Sentry Performance 与 OTEL 可并行；生产建议 trace 以 OTEL → Tempo 为准，Sentry 仅采样关联。

### 2.5 示例异常（验收）

部署 hello 后执行：

```bash
kubectl exec -n dev deploy/hello -- wget -qO- http://127.0.0.1:8080/debug/sentry-test
```

或在 Pod 内：

```go
sentry.CaptureMessage("baobao T0.8 sentry smoke test")
```

**推荐**：在 hello 服务临时添加 `GET /debug/sentry-test`（仅 dev/staging 启用），handler 内 `sentry.CaptureException(errors.New("T0.8 smoke test"))`。

本地验证：

```bash
export SENTRY_DSN="https://..."
export OTEL_EXPORTER_OTLP_ENDPOINT=localhost:4317
make run
curl localhost:8080/debug/sentry-test  # 需自行添加路由
```

Sentry Issues 页应出现 `T0.8 smoke test`，Environment=`dev`。

---

## 3. iOS 接入

详见 [ios-integration.md](./ios-integration.md)。

---

## 4. 采样与 PII

- **生产** `TracesSampleRate` ≤ 0.1；崩溃与 error 全量上报。
- 禁止上报：Token、手机号、Apple Sub、精确 GPS。
- 使用 `BeforeSend` 脱敏：

```go
sentry.Init(sentry.ClientOptions{
    BeforeSend: func(event *sentry.Event, hint *sentry.EventHint) *sentry.Event {
        // 删除 Authorization header 等
        return event
    },
})
```

---

## 5. 告警（T7.10 扩展）

Sentry Alert Rules → 钉钉/飞书 Webhook（凭据入 Vault `secret/{env}/shared/alerting`）。

当前 T0.8 仅需确认 Issues 收到 smoke test 即可。
