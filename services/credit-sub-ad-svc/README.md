# credit-sub-ad-svc

积分 / 订阅 / 广告服务（T4.1 骨架），端口 **8006**。

## 能力（T4.1）

| 组件 | 说明 |
| --- | --- |
| PostgreSQL DDL | 7 张表 + 索引（design-backend §4.1.3） |
| memory / postgres | 双后端 store factory |
| 迁移 | embed + 启动时自动 up；Makefile `migrate-up/down` |
| gRPC | 占位 server（T4.3 saga RPC） |

## API（T4.1）

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/health` | 存活探针 |
| GET | `/ready` | 就绪探针 |

业务 API 见 T4.2–T4.10。

## 表结构

| 表 | 主键 / 唯一约束 | 索引 |
| --- | --- | --- |
| `credit_balances` | PK(`user_id`) | — |
| `credit_ledger` | PK(`id`); UK(`ref_kind`, `ref_id`) | IDX(`user_id`, `created_at` DESC) |
| `credit_holds` | PK(`id`); UK(`ai_task_id`) | — |
| `iap_receipts` | PK(`id`); UK(`transaction_id`) | — |
| `subscriptions` | PK(`id`); UK(`original_transaction_id`) | IDX(`user_id`) |
| `ad_rewards` | PK(`id`); UK(`network`, `signature`) | — |
| `sign_ins` | PK(`user_id`, `date`) | — |

## 环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `SERVICE_NAME` | `credit-sub-ad-svc` | 服务名 |
| `HTTP_PORT` | `8006` | REST 端口 |
| `GRPC_PORT` | `9006` | gRPC 端口 |
| `STORAGE_BACKEND` | `memory` | `memory` 或 `postgres` |
| `DATABASE_URL` | （空） | `STORAGE_BACKEND=postgres` 时必填 |

## 命令

```bash
make build
make test
make run

# 手动迁移（需 DATABASE_URL）
make migrate-up
make migrate-down
```

## 验证

```bash
curl -s localhost:8006/health
curl -s localhost:8006/ready
```

## 参考

- [design-backend.md §4.1.3 / §6](../../docs/design-backend.md)
- [infra/vault/secrets-template/credit-sub-ad.env.example](../../infra/vault/secrets-template/credit-sub-ad.env.example)
