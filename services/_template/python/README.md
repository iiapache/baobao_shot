# Python 微服务模板（caption-svc）

Fork 本目录创建 Python 微服务（如 `caption-svc`）。

## 快速 fork

```bash
cp -r services/_template/python services/caption-svc
cd services/caption-svc
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8007
```

## 验证

```bash
curl localhost:8007/health
curl localhost:8007/ready
curl localhost:8007/v1/caption/generate
```

## 参考

- [design-backend.md §3 — caption-svc](../../../docs/design-backend.md#31-服务清单)
- 端口默认 **8007**（内部 gRPC 服务走 Go 模板）
