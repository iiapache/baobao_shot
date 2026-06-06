# 基础设施配置

> K8s、Helm、ArgoCD、CI/CD 相关配置。

## 目录结构

```text
infra/
├── ci/               # GitLab CI 脚本、Dockerfile 模板、变量说明
├── argocd/           # ApplicationSet、蓝绿 values（T0.2）
├── k8s/              # Helm charts、集群 values、Application 模板（T0.3）
├── gateway/          # APISIX 网关、路由、TLS、域名映射（T0.6）
├── data/             # PostgreSQL / MongoDB / Redis 部署模板（T0.4）
├── messaging/        # Kafka topic、Helm、收发验收脚本（T0.5）
├── storage/          # OSS（CN）/ S3（OS）桶策略、生命周期、CDN（T0.5）
├── vault/            # Vault 策略与 secrets 模板（T0.7 / T0.12）
├── observability/    # Prometheus / Grafana / Loki / Tempo / Sentry（T0.8）
├── accounts/         # 第三方账号清单
└── docs/             # 运维文档（含分支保护说明）
```

## CI/CD 入口

- [infra/ci/README.md](./ci/README.md) — GitLab CI pipeline、docker-build.sh、变量说明
- [infra/argocd/README.md](./argocd/README.md) — 蓝绿 / ApplicationSet
- [infra/k8s/README.md](./k8s/README.md) — K8s 双集群、Helm、单服务 Application
- [infra/gateway/README.md](./gateway/README.md) — APISIX 网关、TLS 1.3、双区域名路由（T0.6）
- [infra/data/README.md](./data/README.md) — PostgreSQL / MongoDB / Redis 双区部署（T0.4）
- [infra/observability/README.md](./observability/README.md) — 监控基线、看板、Sentry 接入（T0.8）

## 相关任务

- T0.2：GitLab CI + ArgoCD（本目录 ci/、argocd/）
- T0.3：K8s 双集群（k8s/）
- T0.4：数据库部署（data/）
- T0.5：Kafka + 双区对象存储（messaging/、storage/）
- T0.6：网关部署（gateway/）
- T0.8：监控基线（observability/）
