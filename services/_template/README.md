# 服务脚手架模板

Go 与 Python 微服务 fork 起点，对应任务 **T0.17**。

## 目录

| 路径 | 说明 |
| --- | --- |
| [`go/`](go/) | Go 微服务模板：REST + gRPC + health + tracing |
| [`python/`](python/) | Python FastAPI 模板（caption-svc 类） |

## 5 分钟 fork 流程

```bash
# Go 服务
cp -r services/_template/go services/my-svc
# 见 go/README.md 替换 module 名

# Python 服务
cp -r services/_template/python services/caption-svc
# 见 python/README.md
```

## 关联

- [design-backend.md §2-3](../docs/design-backend.md)
- [tools/protobuf/](../tools/protobuf/) — protobuf 工具链
- [contracts/](../contracts/) — API 契约（T0.18）
