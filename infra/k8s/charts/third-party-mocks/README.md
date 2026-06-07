# third-party-mocks Helm Chart

Staging 命名空间内部署 WireMock 三方 Mock（对齐 [tests/mocks](../../../../tests/mocks/)）。

## 前置：同步映射

```bash
./infra/staging/scripts/sync-mock-mappings.sh
```

将 `tests/mocks/{iap,wechat,ad,audit,ai}/mappings` 复制到 `bundled-mappings/`。

## 安装

```bash
cd infra/k8s/charts/third-party-mocks
helm dependency update

# ACK CN
helm upgrade --install third-party-mocks . \
  -n staging \
  -f ../../clusters/ack-cn/staging-third-party-mocks-values.yaml

# 验证
kubectl get pods,svc -n staging -l baobao.io/component=third-party-mocks
```

## Service DNS

| Mock | ClusterIP Service | 端口 |
| --- | --- | --- |
| mock-iap | `mock-iap` | 8080 |
| mock-wechat | `mock-wechat` | 8080 |
| mock-ad | `mock-ad` | 8080 |
| mock-audit | `mock-audit` | 8080 |
| mock-ai | `mock-ai` | 8080 |

完整 outbound URL 见 [infra/staging/outbound-mapping.yaml](../../../staging/outbound-mapping.yaml)。

## 静态校验（无需集群）

```bash
helm dependency update
helm lint .
helm template third-party-mocks . -n staging \
  -f ../../clusters/ack-cn/staging-third-party-mocks-values.yaml
```

`bundled-mappings/` 为空时 ConfigMap/Deployment 不会渲染对应 mock — 须先执行 sync 脚本。
