# Jaeger（可选替代 Tempo）

> 默认使用 [tempo/values-dev.yaml](../tempo/values-dev.yaml)（Grafana LGTM 栈）。  
> 若需 Jaeger UI，可按本节部署并将 otel-collector exporter 指向 Jaeger。

## Helm 部署

```bash
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm upgrade --install jaeger jaegertracing/jaeger \
  -n observability \
  -f infra/observability/jaeger/values-dev.yaml
```

## otel-collector 切换

在 `otel-collector/values-dev.yaml` 中将 traces exporter 改为：

```yaml
exporters:
  otlp/jaeger:
    endpoint: jaeger-collector.observability.svc:4317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      exporters: [otlp/jaeger, spanmetrics]  # 替换 otlp/tempo
```

Grafana 可添加 Jaeger datasource 指向 `http://jaeger-query.observability.svc:16686`。

## 与 Go template 对齐

服务侧无需改动，`OTEL_EXPORTER_OTLP_ENDPOINT=otel-collector.observability.svc:4317` 不变。
