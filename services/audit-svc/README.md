# audit-svc

内容审核服务（T3.3），端口 **8005**。

## 能力

| 组件 | 说明 |
| --- | --- |
| `audit_jobs` / `appeals` | PostgreSQL DDL + memory 后端 |
| 状态机 | `pending` → `passed` / `rejected` |
| 三类管线 | `AuditPipeline`：input / output / ugc |
| 同步 RPC | gRPC handler `SyncAudit` / `SubmitAppeal`（proto 待 T3.4 接入） |
| Kafka | `feed.events` 消费 stub + `HandleMessage` 可测 |

## API

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/health` | 存活探针 |
| GET | `/ready` | 就绪探针 |
| POST | `/v1/audit/sync` | 同步审核（input/output/ugc-text） |
| POST | `/v1/appeals` | 提交申诉（仅 rejected 任务） |

## 环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `SERVICE_NAME` | `audit-svc` | 服务名 |
| `HTTP_PORT` | `8005` | REST 端口 |
| `GRPC_PORT` | `9005` | gRPC 端口 |
| `STORAGE_BACKEND` | `memory` | `memory` 或 `postgres` |
| `DATABASE_URL` | （空） | `STORAGE_BACKEND=postgres` 时必填 |
| `KAFKA_BROKERS` | （空） | 非空时启用 consumer stub |
| `KAFKA_TOPIC` | `feed.events` | 消费 topic |
| `KAFKA_GROUP_ID` | `audit-svc` | consumer group |
| `ALIYUN_GREEN_MOCK_MODE` | `true`（无 AK/Endpoint 时） | CN 内容安全 mock 模式（进程内规则） |
| `ALIYUN_GREEN_ENDPOINT` | （空） | 非 mock 时指向 mock-audit 或 Green 代理 URL |
| `ALIYUN_GREEN_ACCESS_KEY_ID` | （空） | 阿里云 Green AK（真厂商 SDK） |
| `ALIYUN_GREEN_ACCESS_KEY_SECRET` | （空） | 阿里云 Green SK |
| `ALIYUN_GREEN_REGION` | `cn-shanghai` | Green 区域（SDK 模式） |
| `ALIYUN_GREEN_OBJECT_URL_PREFIX` | `https://oss-mock.example.com` | 图像/视频 OSS 公网 URL 前缀 |
| `ALIYUN_GREEN_IMAGE_SCENE` | `porn,terrorism,ad,qrcode,live` | 图像审核场景 |
| `ALIYUN_GREEN_TEXT_SCENE` | `antispam` | 文字审核场景 |

## 命令

```bash
make build
make test
make run
```

## 验证

```bash
curl -s localhost:8005/health

curl -s -X POST localhost:8005/v1/audit/sync \
  -H 'Content-Type: application/json' \
  -d '{"kind":"input","targetRef":"tsk_demo","region":"cn","text":"hello"}' | jq .

curl -s -X POST localhost:8005/v1/appeals \
  -H 'Content-Type: application/json' \
  -d '{"auditJobId":"<rejected job id>","userId":"usr_demo","reason":"误判"}' | jq .
```

## 参考

- [design-backend.md §4.1.5 / §7](../../docs/design-backend.md)
- [infra/vault/secrets-template/audit.env.example](../../infra/vault/secrets-template/audit.env.example)
