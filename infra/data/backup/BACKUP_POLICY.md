# 数据层每日备份策略

> 对应 T0.4 验收：PostgreSQL / MongoDB / Redis 每日备份；双区（ack-cn / eks-os）**独立执行**，互不复制。

## 1. 总则

| 项 | 策略 |
| --- | --- |
| 备份频率 | **每日 1 次**（UTC 02:00，各区按本地运维窗口微调） |
| 保留周期 | 日备 7 天、周备 4 周、月备 12 个月 |
| 加密 | 传输 TLS + 静态 AES-256（云厂商默认或 KMS） |
| 验证 | 每周随机抽取 1 份备份做恢复演练 |
| 告警 | 备份失败 / 超时 → 飞书 + 钉钉（P1） |

---

## 2. PostgreSQL 15

### 2.1 备份方式

| 环境 | 方式 | 工具 |
| --- | --- | --- |
| dev / staging | 逻辑备份 `pg_dump` | CronJob |
| prod-cn / prod-os | 物理基础备份 + WAL 归档 | `pg_basebackup` + WAL-G 或云 RDS 自动备份 |

### 2.2 每日 CronJob 示例（逻辑备份，dev/staging）

```yaml
# infra/data/backup/cronjob-postgresql-logical.yaml（模板，部署前替换 Secret）
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgresql-daily-backup
  namespace: dev
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: backup
              image: postgres:15-alpine
              env:
                - name: PGPASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: baobao-postgresql
                      key: password
                - name: BACKUP_BUCKET
                  value: "s3://baobao-backup-${REGION}/postgresql"  # CN 用 OSS 等价路径
              command:
                - /bin/sh
                - -c
                - |
                  TS=$(date +%Y%m%d-%H%M%S)
                  FILE="/tmp/baobao-${TS}.dump"
                  pg_dump -h postgresql -U baobao -Fc baobao -f "${FILE}"
                  # 上传至对象存储（示例占位，按云厂商 SDK/CLI 替换）
                  aws s3 cp "${FILE}" "${BACKUP_BUCKET}/${TS}.dump" || \
                    ossutil cp "${FILE}" "oss://baobao-backup-cn/postgresql/${TS}.dump"
                  echo "backup done: ${TS}"
```

### 2.3 生产 WAL 归档

- 启用 `archive_mode = on`，`archive_command` 推送 WAL 至对象存储。
- RPO ≤ 5 分钟（WAL 连续归档）；RTO ≤ 30 分钟（PITR 恢复演练目标）。

### 2.4 存储位置

| 集群 | 备份存储 |
| --- | --- |
| ack-cn | 阿里云 OSS `baobao-backup-cn/{env}/postgresql/` |
| eks-os | AWS S3 `baobao-backup-os/{env}/postgresql/` |

---

## 3. MongoDB 6

### 3.1 备份方式

| 环境 | 方式 |
| --- | --- |
| dev / staging | `mongodump --gzip` |
| prod | 副本集 `mongodump` 从 secondary 节点执行，避免打主节点 |

### 3.2 每日脚本要点

```bash
TS=$(date +%Y%m%d-%H%M%S)
OUT="/tmp/mongo-${TS}"
mongodump \
  --uri="${MONGODB_URI}" \
  --gzip \
  --archive="${OUT}.gz"
# 上传 OSS/S3
```

### 3.3 保留与索引

- 备份包含 `baobao` 库及 `ai_tasks` 集合（design-backend §4.2）。
- 恢复后验证索引：`userId_1_createdAt_-1`、`state_1_createdAt_1`。

### 3.4 存储位置

| 集群 | 路径 |
| --- | --- |
| ack-cn | `oss://baobao-backup-cn/{env}/mongodb/` |
| eks-os | `s3://baobao-backup-os/{env}/mongodb/` |

---

## 4. Redis 7

### 4.1 备份方式

Redis 为缓存 + 会话态，**可重建数据**为主；仍执行每日 RDB/AOF 快照备灾。

| 环境 | 方式 |
| --- | --- |
| 全部 | `BGSAVE` 触发 RDB，复制 `/data/dump.rdb` 至对象存储 |
| prod | AOF `appendonly yes` 已启用（见 redis values），额外归档 AOF |

### 4.2 每日 CronJob 要点

```bash
redis-cli -h redis-master -a "${REDIS_PASSWORD}" --no-auth-warning BGSAVE
# 等待 save 完成
redis-cli -h redis-master -a "${REDIS_PASSWORD}" --no-auth-warning LASTSAVE
# kubectl cp 或 sidecar 上传 dump.rdb
```

### 4.3 保留策略

- RDB 快照保留 **7 天**（Redis 数据可丢失时 RPO 可接受 24h）。
- Token 黑名单、Feed 缓存丢失可自愈，恢复优先级低于 PG/Mongo。

---

## 5. 备份监控与告警

| 指标 | 阈值 | 告警 |
| --- | --- | --- |
| `backup_last_success_timestamp` | > 26h 未更新 | P1 |
| `backup_duration_seconds` | > 3600 | P2 |
| `backup_size_bytes` | 较 7 日均值偏差 > 50% | P2（可能备份不完整） |

Exporter 由 T0.8 监控基线统一接入 Prometheus；CronJob 结束时写 Pushgateway 或结构化日志供 Loki 解析。

---

## 6. 恢复演练 SOP（摘要）

1. 在 **隔离命名空间** `restore-test` 拉起临时实例。
2. 从最新日备恢复 PG / Mongo / Redis RDB。
3. 执行 `./scripts/connectivity-test.sh` 验证读写。
4. 对 PG 跑 `SELECT count(*)` 抽样核心表；对 Mongo 查 `ai_tasks` 样本。
5. 记录 RTO 实际耗时，写入运维周报。

---

## 7. 合规说明

- ack-cn 与 eks-os 备份数据**不得跨境复制**。
- 备份桶启用版本控制 + 禁止公共读 + 生命周期转低频存储（> 90 天）。
