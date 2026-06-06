# 慢查询监控接入 Prometheus

> 对应 T0.4 验收：PostgreSQL / MongoDB / Redis 慢查询/慢操作监控接入 Prometheus；完整看板由 T0.8 监控基线统一交付。

## 1. 阈值配置（与 values 一致）

| 组件 | 慢查询定义 | 配置位置 |
| --- | --- | --- |
| PostgreSQL 15 | `log_min_duration_statement = 500`（500ms） | `postgresql/values.yaml` → `primary.extendedConfiguration` |
| MongoDB 6 | `slowOpThresholdMs: 100` | `mongodb/values.yaml` → `configuration` |
| Redis 7 | `slowlog-log-slower-than 10000`（10ms） | `redis/values.yaml` → `master.configuration` |

本地 docker-compose 已同步上述参数（见 `docker-compose.dev.yml`）。

---

## 2. Exporter 部署

Bitnami charts 已启用 `metrics.enabled: true`。T0.8 部署 Prometheus Operator 后，将各 chart 的 `metrics.serviceMonitor.enabled` 设为 `true`。

### 2.1 ServiceMonitor 示例（PostgreSQL）

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: postgresql
  namespace: dev
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: postgresql
  endpoints:
    - port: metrics
      interval: 30s
```

MongoDB / Redis 同理，匹配 `app.kubernetes.io/name: mongodb` / `redis`。

### 2.2 额外 Exporter（推荐生产）

| 组件 | Exporter | 端口 | 慢查询相关指标 |
| --- | --- | --- | --- |
| PostgreSQL | `postgres_exporter` + `pg_stat_statements` | 9187 | `pg_stat_statements_*` |
| MongoDB | `mongodb_exporter` | 9216 | `mongodb_mongod_op_latencies_*` |
| Redis | `redis_exporter` | 9121 | `redis_slowlog_length` |

Bitnami 内置 metrics 已包含基础指标；生产建议叠加社区 exporter 获取更细粒度慢 SQL。

---

## 3. PostgreSQL 慢查询

### 3.1 pg_stat_statements

values 已启用：

```ini
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
pg_stat_statements.max = 10000
```

### 3.2 常用 PromQL

```promql
# 平均执行时间 Top N（需 postgres_exporter 暴露 pg_stat_statements）
topk(10, rate(pg_stat_statements_mean_exec_time_seconds[5m]))

# 慢查询日志行数（若 promtail 解析 PG log）
sum(rate({job="postgresql"} |= "duration:" [5m]))
```

### 3.3 日志采集（Loki）

Promtail 抓取 PostgreSQL 日志，过滤 `duration:` 字段：

```yaml
# promtail pipeline 片段
- match:
    selector: '{app="postgresql"}'
    stages:
      - regex:
          expression: 'duration: (?P<duration_ms>[0-9.]+) ms'
      - metrics:
          postgresql_slow_query_total:
            type: Counter
            description: "PG queries exceeding log_min_duration_statement"
            source: duration_ms
            config:
              action: inc
```

---

## 4. MongoDB 慢操作

### 4.1 Profiler

`operationProfiling.mode: slowOp` + `slowOpThresholdMs: 100` 已写入 chart values。

### 4.2 查询 system.profile

```javascript
db.system.profile.find({ millis: { $gt: 100 } }).sort({ ts: -1 }).limit(20)
```

### 4.3 Prometheus 指标

```promql
# mongodb_exporter 操作延迟
histogram_quantile(0.95, rate(mongodb_mongod_op_latencies_latency_bucket[5m]))

# 慢操作计数（若自定义 exporter 暴露 profile 统计）
rate(mongodb_profile_slow_ops_total[5m])
```

---

## 5. Redis 慢日志

### 5.1 配置

```conf
slowlog-log-slower-than 10000   # 微秒，即 10ms
slowlog-max-len 256
```

### 5.2 redis_exporter 指标

```promql
# 慢日志条目数
redis_slowlog_length{instance="redis-master:6379"}

# 命令延迟 P95
histogram_quantile(0.95, rate(redis_commands_duration_seconds_bucket[5m]))
```

### 5.3 手动查看

```bash
redis-cli -a "${REDIS_PASSWORD}" --no-auth-warning SLOWLOG GET 20
```

---

## 6. Grafana 看板建议（T0.8 集成）

| 面板 | 数据源 | 说明 |
| --- | --- | --- |
| PG 慢 SQL Top 10 | Prometheus | `pg_stat_statements` |
| PG 慢查询速率 | Loki | 日志 `duration:` 解析 |
| Mongo 慢操作 P95 | Prometheus | `mongodb_mongod_op_latencies_*` |
| Redis 慢命令 | Prometheus + 日志 | `redis_slowlog_length` |
| 备份与慢查关联 | Grafana 注释 | 备份窗口标记，排除批量任务误报 |

---

## 7. 告警规则示例

```yaml
groups:
  - name: baobao-data-slow-query
    rules:
      - alert: PostgreSQLSlowQueryRateHigh
        expr: rate(pg_stat_statements_calls{query!~"COPY.*"}[5m]) > 10
          and avg(pg_stat_statements_mean_exec_time_seconds) > 0.5
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "PostgreSQL 慢查询速率升高"

      - alert: MongoDBSlowOpP95High
        expr: histogram_quantile(0.95, rate(mongodb_mongod_op_latencies_latency_bucket[5m])) > 0.1
        for: 10m
        labels:
          severity: warning

      - alert: RedisSlowlogGrowing
        expr: increase(redis_slowlog_length[15m]) > 50
        for: 5m
        labels:
          severity: warning
```

---

## 8. 接入检查清单

| 项 | 命令 / 检查 | 预期 |
| --- | --- | --- |
| PG 扩展 | `SHOW shared_preload_libraries;` | 含 `pg_stat_statements` |
| PG 慢日志 | `SHOW log_min_duration_statement;` | `500ms` |
| Mongo profiler | `db.getProfilingStatus()` | level 1, slowms 100 |
| Redis slowlog | `CONFIG GET slowlog-log-slower-than` | `10000` |
| Exporter | `curl postgresql-metrics:9187/metrics` | HTTP 200 |
| ServiceMonitor | `kubectl get servicemonitor -n dev` | postgresql/mongodb/redis 存在（T0.8） |
