# feed-svc

发布 / Feed / 点赞 / 评论服务（T5.1 骨架），端口 **8002**。

## 能力（T5.1）

| 组件 | 说明 |
| --- | --- |
| PostgreSQL DDL | 5 张表 + 索引（design-backend §4.1.2） |
| memory / postgres | 双后端 store factory |
| 迁移 | embed + 启动时自动 up；Makefile `migrate-up/down` |
| gRPC | FeedService 占位（GetPost） |
| REST | `/health` / `/ready` |

业务 API 见 T5.2–T5.5。

## 表结构

| 表 | 主键 / 唯一约束 | 索引 |
| --- | --- | --- |
| `posts` | PK(`id`) | IDX(`family_id`, `created_at` DESC)、IDX(`owner_user_id`)、部分 IDX 活跃帖 |
| `post_items` | PK(`id`) | IDX(`post_id`) |
| `comments` | PK(`id`) | IDX(`post_id`, `created_at`) |
| `likes` | PK(`post_id`, `user_id`) | — |
| `feed_audit_logs` | PK(`id`) | IDX(`target_kind`, `target_id`) |

软删：`posts` / `post_items` / `comments` 含 `deleted_at`；`likes` 取消即物理删；`feed_audit_logs` 为审计流水不可删。

## 环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `SERVICE_NAME` | `feed-svc` | 服务名 |
| `HTTP_PORT` | `8002` | REST 端口 |
| `GRPC_PORT` | `9002` | gRPC 端口 |
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

## Postgres 集成测试

设置 `TEST_DATABASE_URL` 后运行 migration round-trip 与 postgres store 单测：

```bash
export TEST_DATABASE_URL='postgres://user:pass@localhost:5432/feed_test?sslmode=disable'
go test ./internal/store/ -run 'Postgres|RoundTrip' -v
```

## 验证

```bash
curl -s localhost:8002/health
curl -s localhost:8002/ready
```

## 参考

- [design-backend.md §4.1.2](../../docs/design-backend.md)
- [design-api.md §7](../../docs/design-api.md)
- [contracts/protobuf/proto/baobao/feed/v1/feed.proto](../../contracts/protobuf/proto/baobao/feed/v1/feed.proto)
