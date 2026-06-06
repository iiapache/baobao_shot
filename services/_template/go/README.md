# Go 微服务模板

Fork 本目录创建新 Go 微服务，5 分钟内可本地启动。

## 快速 fork

```bash
# 1. 复制模板
cp -r services/_template/go services/auth-family-svc

# 2. 替换模块名（示例）
cd services/auth-family-svc
find . -type f -name '*.go' -exec sed -i '' 's|github.com/baobao/template|github.com/baobao/auth-family-svc|g' {} +
sed -i '' 's|module github.com/baobao/template|module github.com/baobao/auth-family-svc|' go.mod

# 3. 设置环境变量并启动
export SERVICE_NAME=auth-family-svc HTTP_PORT=8001 GRPC_PORT=9001
make tidy run
```

## 目录结构

```text
go/
├── cmd/server/main.go          # 入口：HTTP + gRPC + 优雅退出
├── internal/
│   ├── config/                 # 环境变量配置
│   ├── handler/rest/           # REST（/health, /ready）
│   ├── handler/grpc/           # gRPC + health + reflection
│   └── middleware/             # Auth 占位 + OpenTelemetry
├── Dockerfile                  # 多阶段构建（复用 infra/ci 模式）
└── Makefile                    # build / test / run / proto
```

## 环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `SERVICE_NAME` | `template` | 服务名，出现在 health JSON |
| `HTTP_PORT` | `8080` | REST 端口 |
| `GRPC_PORT` | `9090` | gRPC 端口 |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | （空） | 设置后启用 OTLP tracing |
| `ENVIRONMENT` | `dev` | 环境标识 |

## 命令

```bash
make build    # 编译到 bin/
make test     # 单测
make run      # 本地运行
make proto    # 从 tools/protobuf 生成 gRPC 代码
make docker   # 构建镜像
```

## 验证

```bash
curl localhost:8080/health   # {"status":"ok","service":"template"}
curl localhost:8080/ready    # {"status":"ready","service":"template"}
```

## 参考

- [design-backend.md §2-3](../../../docs/design-backend.md)
- [tools/protobuf](../../../tools/protobuf/) — protobuf 工具链
- [infra/ci/Dockerfile.template](../../../infra/ci/Dockerfile.template)
