# 监控基线（T0.8）

> Prometheus + Grafana + Loki + Tempo + Sentry + OpenTelemetry Collector  
> 模板看板：API RPS/P95、5xx、节点资源

## 目录结构

```text
observability/
├── README.md                          # 本文件
├── scripts/deploy-dev.sh              # dev 一键部署
├── k8s/namespace.yaml
├── prometheus/
│   ├── values-dev.yaml                # kube-prometheus-stack
│   └── scrape-configs/
│       ├── additional-scrape-configs.yaml   # hello / gateway / otel
│       ├── hello-servicemonitor.yaml
│       ├── gateway-servicemonitor.yaml
│       └── gateway-prometheus-values-snippet.yaml
├── grafana/dashboards/
│   ├── api-overview.json              # API RPS / P95 / 5xx
│   └── node-resources.json            # 节点 CPU / 内存 / 磁盘
├── loki/values-dev.yaml
├── tempo/values-dev.yaml              # 分布式追踪（Jaeger 兼容查询）
├── otel-collector/
│   ├── config.yaml                    # 独立 config（本地复用）
│   └── values-dev.yaml                # Helm deployment
├── sentry/
│   ├── README.md                      # Sentry 总览
│   ├── go-integration.md              # Go SDK
│   └── ios-integration.md             # iOS SDK
└── examples/
    └── hello-observability.yaml       # hello 接入示例
```

## 架构

```text
┌─────────────┐  OTLP gRPC   ┌──────────────────┐   traces   ┌───────┐
│ Go 微服务    │─────────────▶│ otel-collector   │───────────▶│ Tempo │
│ (template)  │  :4317       │  spanmetrics     │           └───────┘
└─────────────┘              │  → :8889         │──metrics──▶ Prometheus
       │                     └────────┬─────────┘                  │
       │ Sentry DSN                   │ logs                       │
       ▼                              ▼                            ▼
┌─────────────┐                    ┌───────┐                  ┌─────────┐
│   Sentry    │                    │ Loki  │◀── Grafana ────│ 看板    │
└─────────────┘                    └───────┘                  └─────────┘
       ▲
┌─────────────┐
│  iOS App    │
└─────────────┘

Prometheus 额外 scrape:
  - hello Pod（/metrics 或 spanmetrics）
  - APISIX gateway（/apisix/prometheus/metrics）
  - node-exporter（kube-prometheus-stack 内置）
```

## 与 Go 服务模板对齐

`services/_template/go` 已内置 OpenTelemetry：

| 环境变量 | 值（K8s dev） | 代码位置 |
| --- | --- | --- |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `otel-collector.observability.svc:4317` | `internal/middleware/tracing.go` |
| `SERVICE_NAME` | 服务名 | `internal/config/config.go` |
| `ENVIRONMENT` | `dev` / `staging` / `prod` | 同上 |

未设置 `OTEL_EXPORTER_OTLP_ENDPOINT` 时 tracing 自动禁用（no-op）。

**指标来源**（无需改模板即可在看板看到数据）：

1. **OTEL spanmetrics**：HTTP 请求经 `otelhttp` 产生 trace → collector 聚合为 `traces_spanmetrics_*` → Prometheus scrape `:8889`
2. **APISIX gateway**：网关层 RPS / 状态码
3. **node-exporter**：节点资源看板

可选：服务自行暴露 `/metrics`（prometheus/client_golang），配合 `hello-servicemonitor.yaml`。

## 一键部署（dev）

```bash
chmod +x infra/observability/scripts/deploy-dev.sh
./infra/observability/scripts/deploy-dev.sh
```

仅 apply K8s 清单（跳过 Helm）：

```bash
./infra/observability/scripts/deploy-dev.sh --skip-helm
```

### 手动分步

```bash
kubectl apply -f infra/observability/k8s/namespace.yaml

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Secret（additional scrape）
kubectl create secret generic prometheus-additional-scrape-configs \
  -n observability \
  --from-file=prometheus-additional-scrape-configs.yaml=infra/observability/prometheus/scrape-configs/additional-scrape-configs.yaml

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  -n observability -f infra/observability/prometheus/values-dev.yaml

helm upgrade --install loki grafana/loki \
  -n observability -f infra/observability/loki/values-dev.yaml

helm upgrade --install tempo grafana/tempo \
  -n observability -f infra/observability/tempo/values-dev.yaml

helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  -n observability -f infra/observability/otel-collector/values-dev.yaml

# 看板 ConfigMap
kubectl create configmap baobao-grafana-dashboards -n observability \
  --from-file=infra/observability/grafana/dashboards/ \
  --dry-run=client -o yaml | kubectl label --local -f - grafana_dashboard=1 -o yaml | kubectl apply -f -
```

### 访问 Grafana

```bash
kubectl port-forward -n observability svc/prometheus-grafana 3000:80
# http://localhost:3000  admin / changeme（dev only）
```

导入看板（sidecar 自动加载）：

- **Baobao API Overview** — RPS、P95、5xx
- **Baobao Node Resources** — CPU、内存、磁盘、Pod

## 服务接入 checklist

任意新 Go 微服务：

1. Fork `services/_template/go`（已含 OTEL HTTP instrumentation）
2. Deployment 注入：
   ```yaml
   env:
     - name: OTEL_EXPORTER_OTLP_ENDPOINT
       value: otel-collector.observability.svc:4317
   ```
3. （可选）Pod 注解 + ServiceMonitor 复制 `hello-servicemonitor.yaml`
4. （可选）Sentry：`SENTRY_DSN` — 见 [sentry/go-integration.md](./sentry/go-integration.md)

Gateway：合并 [gateway-prometheus-values-snippet.yaml](./prometheus/scrape-configs/gateway-prometheus-values-snippet.yaml)，apply `gateway-servicemonitor.yaml`。

数据库 exporter ServiceMonitor：见 [infra/data/monitoring/slow-query.md](../data/monitoring/slow-query.md)（`release: prometheus`）。

## Sentry 验收

1. Vault 写入 DSN（见 [sentry/README.md](./sentry/README.md)）
2. Go：`SENTRY_DSN` + smoke test 路由
3. iOS：Debug 按钮 `SentrySDK.capture(error:)` — 见 [sentry/ios-integration.md](./sentry/ios-integration.md)
4. Sentry Issues 出现 `T0.8 smoke test`

## 验收自检

| 项 | 命令 / 操作 | 期望 |
| --- | --- | --- |
| Prometheus UP | `kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090` → Targets | hello / gateway / otel-collector 为 UP |
| API 看板 | Grafana → Baobao API Overview | 对 hello 发 curl 后 RPS > 0 |
| P95 / 5xx | 同上 | spanmetrics 有 latency 曲线 |
| 节点看板 | Baobao Node Resources | CPU/内存曲线正常 |
| Tracing | Grafana → Explore → Tempo | 按 service.name=hello 查到 trace |
| Loki | Grafana → Explore → Loki | `{service_name="hello"}` 有日志（若服务 OTLP logs） |
| Sentry | Issues 页 | Go + iOS smoke test 各 1 条 |

### 快速冒烟

```bash
# 1. 部署栈
./infra/observability/scripts/deploy-dev.sh

# 2. hello 打流量（假设 hello 在 dev namespace）
kubectl port-forward -n dev svc/hello 8080:80 &
for i in $(seq 1 20); do curl -s localhost:8080/health; done

# 3. Prometheus 查询
# rate(traces_spanmetrics_calls_total{service_name="hello"}[5m])

# 4. Sentry — 按 sentry/README.md 触发 smoke test
```

## 相关任务

- **T0.4**：数据库 exporter → 本栈 Prometheus 抓取（slow-query.md）
- **T0.7**：Vault 存储 Sentry DSN / Grafana admin 密码
- **T7.10**：告警规则 + on-call（在本基线上扩展）

## Tempo vs Jaeger

本项目选用 **Tempo**（Grafana LGTM 栈原生集成）。Tempo 支持 Jaeger query API；若团队强制 Jaeger UI，可额外部署 `jaegertracing/jaeger` 并将 otel-collector exporter 改为 `jaeger`。

```yaml
# otel-collector 替代 exporter（未默认启用）
exporters:
  jaeger:
    endpoint: jaeger-collector.observability.svc:14250
    tls:
      insecure: true
```

## 生产差异（staging/prod）

- Grafana admin 密码 / Sentry DSN 从 Vault 注入
- Prometheus retention ≥ 30d；Loki/Tempo 对象存储（S3/OSS）
- `tls.insecure: false` + mTLS for OTLP
- Alertmanager → 钉钉/飞书（T7.10）
