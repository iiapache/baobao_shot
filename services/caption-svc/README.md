# caption-svc

智能文案生成服务（Python FastAPI）。T5.6 提供轻量模型 stub、每日限额与 Redis 响应缓存。

## 能力

| 接口 | 说明 |
| --- | --- |
| `GET /health` | 存活探针 |
| `GET /ready` | 就绪探针（检查 Redis / 内存存储） |
| `POST /v1/caption/generate` | 生成 3 条候选文案（stub） |

- 每日限额：**50 次/账号**（`CAPTION_DAILY_LIMIT` → HTTP 429）
- 相同请求参数命中 Redis 缓存，不重复扣减当日额度
- 国内区 stub 标注通义千问 Turbo；海外区标注 GPT-4o-mini

## 快速启动

需要 **Python 3.11+**（与 Dockerfile 一致）。

```bash
cd services/caption-svc
python3.11 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8007
```

## 环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `HTTP_PORT` | `8007` | 监听端口 |
| `REGION` | `cn` | `cn` / `os`，影响 stub 模型标注 |
| `REDIS_URL` | （空） | 未配置时使用内存存储（本地开发） |
| `DAILY_LIMIT` | `50` | 每账号每日生成次数 |
| `CACHE_TTL_SECONDS` | `604800` | 响应缓存 TTL（7 天） |

## 调用示例

```bash
curl -s localhost:8007/health
curl -s localhost:8007/ready

curl -s -X POST localhost:8007/v1/caption/generate \
  -H 'Authorization: Bearer dev' \
  -H 'Content-Type: application/json' \
  -d '{"babyId":"bb_01HZ","ageDays":312,"play":"ghibli_kid","location":"杭州"}'
```

开发鉴权（与 Go 服务一致）：

- 网关转发 `X-User-Id`
- `Authorization: Bearer dev` → `usr_dev`
- `Authorization: Bearer dev:<userId>`
- `Authorization: Bearer atk_<userId>_<suffix>`

## 测试

```bash
pytest -q
```

## 参考

- [design-api.md §9 智能文案](../../docs/design-api.md#9-智能文案)
- [design-backend.md §3 — caption-svc](../../docs/design-backend.md#31-服务清单)
- OpenAPI：`contracts/openapi/paths/caption.yaml`
