# 消息队列（Kafka）

> T0.5 产出 — Kafka 3 broker + 业务 topic 定义  
> 参考：[design-backend.md §3.2](../../docs/design-backend.md)

## 目录

```text
infra/messaging/
├── kafka/
│   ├── topics.yaml              # topic 定义（事件总线 + 内部 Worker 队列）
│   ├── helm-values.yaml         # 生产 3 broker Bitnami Helm
│   └── docker-compose.kafka.yaml # 本地单 broker 片段
└── scripts/
    └── produce-consume-test.sh  # 收发验收
```

## Topic 一览

| Topic | 分区 | 保留 | 生产者 | 消费者 |
| --- | --- | --- | --- | --- |
| `ai.events` | 3 | 7d | ai-dispatch-svc | notification-svc |
| `iap.events` | 3 | 14d | iap-callback-svc | credit-sub-ad-svc |
| `feed.events` | 3 | 7d | feed-svc | notification-svc |
| `credit.events` | 3 | 14d | credit-sub-ad-svc, ai-dispatch-svc | notification-svc |

内部 Worker 队列（T3.6）：`ai.image`、`ai.video` — 见 [topics.yaml](./kafka/topics.yaml) `internalTopics`。

## 部署

### 生产（K8s Helm）

```bash
helm install kafka oci://registry-1.docker.io/bitnamicharts/kafka \
  -f infra/messaging/kafka/helm-values.yaml \
  -n baobao-messaging --create-namespace
```

- 3 broker + 3 controller（KRaft）
- `auto.create.topics.enable=false`，由 chart `provisioning` 预创建 4 个事件 topic
- SASL 密码通过 Vault / External Secrets 注入，禁止写入仓库

### 本地（Docker Compose）

```bash
docker compose -f infra/messaging/kafka/docker-compose.kafka.yaml up -d
```

外部访问：`localhost:9094`（容器内 `kafka:9092`）

## 验收

```bash
chmod +x infra/messaging/scripts/produce-consume-test.sh
./infra/messaging/scripts/produce-consume-test.sh
# 期望：RESULT: PASS (4/4 topics)
```

可选环境变量：

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `KAFKA_BOOTSTRAP_SERVERS` | `localhost:9094` | bootstrap 地址 |
| `KAFKA_TEST_TIMEOUT_SEC` | `30` | broker 等待超时 |
