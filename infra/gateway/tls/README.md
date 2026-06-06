# TLS 1.3 强制与 HTTP/2 配置说明

> 对应 design-backend §9.1（TLS 终止 + HTTP/2）、design.md §3.2（HTTP/2 + TLS 1.3）、T0.6 验收标准。

## 目标

| 项 | 要求 | 实现位置 |
| --- | --- | --- |
| TLS 终止 | 网关层终止 HTTPS，后端 ClusterIP HTTP | APISIX gateway Service :443 |
| TLS 1.3 强制 | 禁用 TLS 1.2 及以下 | `charts/baobao-gateway/values.yaml` → `apisix.set_config.apisix.ssl.ssl_protocols` |
| HTTP/2 | 客户端到网关启用 h2 | `apisix.enableHttp2: true`（SSL 启用时 APISIX 默认支持 ALPN h2） |
| 证书管理 | 自动续期 | cert-manager + `tls/cluster-issuer.yaml` |

## APISIX 配置（Helm values）

```yaml
# infra/gateway/charts/baobao-gateway/values.yaml
apisix:
  ssl:
    enabled: true
  enableHttp2: true
  set_config:
    apisix:
      ssl:
        ssl_protocols: "TLSv1.3"
        ssl_ciphers: "TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256"
        ssl_prefer_server_ciphers: "on"
```

说明：

- `ssl_protocols: TLSv1.3` 仅允许 TLS 1.3 握手；TLS 1.2 客户端将被拒绝（符合「强制 TLS 1.3」）。
- `enableHttp2: true` 在 APISIX 数据面启用 HTTP/2 listener；与 TLS 共用 443 端口，通过 ALPN 协商 `h2`。
- 后端到微服务仍为 HTTP/1.1 ClusterIP（集群内网，不重复 TLS）。

## cert-manager 集成

1. 安装 cert-manager CRD 与 controller。
2. `kubectl apply -f infra/gateway/tls/cluster-issuer.yaml`（先替换 DNS solver 占位）。
3. Certificate 就绪后 Secret 写入 `gateway` 命名空间。
4. `ApisixTls` 资源将 Secret 绑定到 SNI（`dev-api-cn.example.com` 等）。

证书私钥算法使用 **ECDSA P-256**，与 TLS 1.3 推荐实践一致。

## HTTP/2 验证

```bash
# 需 DNS 或 --resolve 指向网关 LB
curl -sI --http2 --tlsv1.3 --tls-max 1.3 \
  --resolve dev-api-cn.example.com:443:127.0.0.1 \
  https://dev-api-cn.example.com/health

# 预期响应头含 HTTP/2 200（curl 输出 "HTTP/2 200"）
```

本地 kind 集群无公网证书时，可用 `--insecure` 跳过校验，仅验证协议协商：

```bash
curl -sI --http2 --insecure -k https://<LB-IP>/health -H "Host: dev-api-cn.example.com"
```

## TLS 1.3 验证

```bash
# OpenSSL — 仅 TLS 1.3 应成功
openssl s_client -connect dev-api-cn.example.com:443 -tls1_3 </dev/null 2>/dev/null | grep "Protocol"

# TLS 1.2 应失败（握手错误）
openssl s_client -connect dev-api-cn.example.com:443 -tls1_2 </dev/null 2>&1 | grep -i "error\|alert"
```

或使用 `scripts/health-check.sh --check-tls`.

## 与 Kong 的等价配置（参考）

若后续切换 Kong，对应配置为：

```yaml
# Kong values 片段（未启用，仅文档对照 design §2）
env:
  ssl_protocols: TLSv1.3
  nginx_http2: "on"
```

本项目选用 APISIX，路由 CRD 见 `routes/`。

## 安全注意事项

- 禁止将 TLS 私钥、ACME 账户密钥提交 Git。
- 生产 `letsencrypt-prod` Issuer 与 staging 分离。
- CDN（`cdn-cn` / `cdn-os`）独立证书，不走 API 网关 Secret。
