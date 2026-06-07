# BabyCamera Metrics Catalog（T7.10）

> 各服务 `/metrics` 端点与 OTEL spanmetrics 指标契约。  
> 看板：`infra/monitoring/grafana/dashboards/babycamera-v1-overview.json`  
> 告警：`infra/monitoring/prometheus/alerts/babycamera-v1.yaml`

## 采集架构

| 来源 | 路径 / 端口 | 说明 |
| --- | --- | --- |
| OTEL spanmetrics | `otel-collector.observability.svc:8889` | 全服务 HTTP RPS / P95 / 5xx（无需改代码） |
| APISIX gateway | `/apisix/prometheus/metrics` | 网关层 RPS / 状态码 |
| 服务自定义 | `GET /metrics`（`:8080` 或 Pod 注解端口） | 业务指标（本文档定义） |

服务 Pod 注解（ServiceMonitor 前置）：

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

## 命名规约

- 前缀：`babycamera_`
- 标签：`service`（服务名）、`region`（`cn` / `os`）、业务维度标签
- Histogram bucket 建议：`0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30, 60, 120, 300`

---

## 通用 HTTP（所有 Go 微服务）

| 指标 | 类型 | 标签 | 说明 |
| --- | --- | --- | --- |
| `babycamera_http_requests_total` | Counter | `service`, `method`, `route`, `status_code`, `region` | HTTP 请求计数 |
| `babycamera_http_request_duration_seconds` | Histogram | `service`, `method`, `route`, `status_code`, `region` | HTTP 延迟 |

**暴露服务**：`auth-family-svc`, `feed-svc`, `media-svc`, `ai-dispatch-svc`, `audit-svc`, `credit-sub-ad-svc`, `caption-svc`, `notification-svc`, `config-svc`, `iap-callback-svc`

**端点**：`GET /metrics`（与 `/health` 同端口）

**OTEL 等价**（已默认启用）：

| OTEL 指标 | 标签 | 看板用途 |
| --- | --- | --- |
| `traces_spanmetrics_calls_total` | `service_name`, `http_status_code`, `region` | RPS、5xx |
| `traces_spanmetrics_duration_milliseconds_bucket` | `service_name`, `region` | P95 |

---

## ai-dispatch-svc（:8004）

| 指标 | 类型 | 标签 | 说明 |
| --- | --- | --- | --- |
| `babycamera_ai_task_total` | Counter | `capability`（`image`/`video`）, `status`（`success`/`failed`/`rejected`/`timeout`）, `region`, `style` | 任务终态计数 |
| `babycamera_ai_task_duration_seconds` | Histogram | `capability`, `status`, `region` | 提交到终态耗时 |
| `babycamera_ai_adapter_queue_depth` | Gauge | `adapter`, `region` | 模型队列深度 |
| `babycamera_ai_adapter_success_rate` | Gauge | `adapter`, `region` | 5 分钟滑动成功率 |

**埋点位置**：`internal/worker/processor.go`（任务终态）、`internal/router/metrics.go`（队列/成功率）

**告警阈值**：成功率 < 95%（10m）；图片 P95 > 60s；视频 P95 > 300s

---

## credit-sub-ad-svc（:8006）

| 指标 | 类型 | 标签 | 说明 |
| --- | --- | --- | --- |
| `babycamera_iap_verify_total` | Counter | `kind`（`credit`/`subscription`）, `result`（`success`/`failed`/`duplicate`）, `region` | IAP 校验 |
| `babycamera_ad_reward_total` | Counter | `network`, `result`（`success`/`failed`/`duplicate`）, `region` | 广告激励回调 |
| `babycamera_credit_reconciliation_discrepancy_total` | Counter | `domain`（`balance`/`hold`/`iap`/`ad`/`model_cost`） | 对账差异条数 |
| `babycamera_credit_reconciliation_last_run_timestamp_seconds` | Gauge | `kind`（`daily`/`manual`） | 上次对账 Unix 时间 |

**埋点位置**：

- IAP：`internal/handler/rest/iap_verify.go`, `subscription.go`
- 广告：`internal/handler/rest/ad_reward.go`
- 对账：`internal/reconciliation/service.go`（`defaultAlert` 时递增 discrepancy counter）

**告警阈值**：IAP 失败率 > 0.5%；对账差异任意 > 0

---

## feed-svc（:8002）

| 指标 | 类型 | 标签 | 说明 |
| --- | --- | --- | --- |
| `babycamera_feed_request_duration_seconds` | Histogram | `route`, `cache_hit`（`true`/`false`）, `region` | Feed 列表延迟 |
| `babycamera_feed_posts_total` | Counter | `action`（`publish`/`delete`/`like`/`comment`）, `region` | Feed 写操作 |
| `babycamera_feed_oss_reconcile_discrepancy_total` | Counter | `kind` | OSS 撤回对账差异（T5.5） |

**埋点位置**：`internal/handler/rest/feed.go`（ListFamily）、`internal/reconciliation/service.go`

**告警阈值**：P95 > 800ms

---

## notification-svc（:8008）

| 指标 | 类型 | 标签 | 说明 |
| --- | --- | --- | --- |
| `babycamera_apns_push_total` | Counter | `category`, `result`（`success`/`failed`/`unregistered`）, `region` | APNs 投递 |
| `babycamera_inbox_write_total` | Counter | `category`, `result`, `region` | 消息中心写入 |
| `babycamera_device_token_total` | Gauge | `region` | 有效 device token 数 |

**埋点位置**：`internal/orchestrator/service.go`（Dispatch）、`internal/apns/client.go`

**告警阈值**：失败率 > 1%（10m）

---

## iap-callback-svc（:8010）

| 指标 | 类型 | 标签 | 说明 |
| --- | --- | --- | --- |
| `babycamera_apple_notification_total` | Counter | `notification_type`, `result`, `region` | Apple Server Notifications v2 |
| `babycamera_iap_event_publish_total` | Counter | `topic`, `result` | Kafka `iap.events` 投递 |

**端点**：`GET /metrics`

---

## audit-svc（:8005）

| 指标 | 类型 | 标签 | 说明 |
| --- | --- | --- | --- |
| `babycamera_audit_request_total` | Counter | `channel`（`input`/`output`/`ugc`）, `result`（`pass`/`reject`/`error`）, `region` | 审核请求 |
| `babycamera_audit_duration_seconds` | Histogram | `channel`, `region` | 审核耗时 |

---

## 服务端口速查

| 服务 | 端口 | `/metrics` | `/health` |
| --- | ---: | :---: | :---: |
| auth-family-svc | 8001 | ✓ | ✓ |
| feed-svc | 8002 | ✓ | ✓ |
| media-svc | 8003 | ✓ | ✓ |
| ai-dispatch-svc | 8004 | ✓ | ✓ |
| audit-svc | 8005 | ✓ | ✓ |
| credit-sub-ad-svc | 8006 | ✓ | ✓ |
| caption-svc | 8007 | ✓ | ✓ |
| notification-svc | 8008 | ✓ | ✓ |
| config-svc | 8009 | ✓ | ✓ |
| iap-callback-svc | 8010 | ✓ | ✓ |

---

## 验证命令

```bash
# 单服务 metrics 端点
curl -s http://localhost:8004/metrics | grep '^babycamera_'

# Prometheus 即时查询（port-forward 9090 后）
# rate(traces_spanmetrics_calls_total{service_name="feed-svc"}[5m])
# sum(increase(babycamera_credit_reconciliation_discrepancy_total[24h])) by (domain)
```

## 接入 checklist（新服务）

1. 引入 `prometheus/client_golang`，注册 `babycamera_*` 指标
2. 路由挂载 `GET /metrics`（参考 `services/_template/go`）
3. Pod 注解 + ServiceMonitor（`infra/observability/prometheus/scrape-configs/`）
4. 更新本文档指标表
5. 在 Grafana 看板验证曲线可见
