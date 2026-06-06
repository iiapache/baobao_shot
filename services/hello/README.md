# hello 演示服务

CI / 网关路由验证用最小 Go 服务，含 health、gRPC 占位与 `/v1/echo`。

## 启动

```bash
cd services/hello
make tidy run
```

## 验证

```bash
curl localhost:8080/health
curl localhost:8080/ready
curl 'localhost:8080/v1/echo?msg=world'
```

gRPC（dev 环境启用 reflection）：

```bash
grpcurl -plaintext localhost:9090 grpc.health.v1.Health/Check
```

## 网关

见 `infra/gateway/routes/hello-api.yaml` — `/health` 与 `/v1/*` 路由到此服务。
