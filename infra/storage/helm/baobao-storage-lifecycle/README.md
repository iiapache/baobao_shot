# Baobao Storage Lifecycle Helm Chart — T3.2

将仓库内 OSS/S3 生命周期规则打包为 ConfigMap，并部署删除事件对账 CronJob（stub）。

## 安装

```bash
# CN（ACK）
helm upgrade --install storage-lifecycle infra/storage/helm/baobao-storage-lifecycle \
  -n baobao-infra --create-namespace \
  -f infra/storage/helm/baobao-storage-lifecycle/values-ack-cn.yaml

# OS（EKS）
helm upgrade --install storage-lifecycle infra/storage/helm/baobao-storage-lifecycle \
  -n baobao-infra --create-namespace \
  -f infra/storage/helm/baobao-storage-lifecycle/values-eks-os.yaml
```

## 内容

| 资源 | 说明 |
| --- | --- |
| ConfigMap `*-lifecycle` | 嵌入 `oss-cn/lifecycle-rules.xml`、`s3-os/lifecycle-rules.json` |
| ConfigMap `*-scripts` | `reconcile-deletes.sh`、`verify-lifecycle.sh` |
| CronJob `*-reconcile` | 每 15 分钟运行对账 stub，日志含 `RECONCILE:` 前缀 |

## 应用生命周期到云桶

Helm 仅打包配置；实际上云需 CLI：

```bash
./infra/storage/scripts/apply-lifecycle.sh all
```

## 验收

```bash
./infra/storage/scripts/verify-lifecycle.sh
RECONCILE_DRY_RUN=1 ./infra/storage/scripts/reconcile-deletes.sh
DELETE_EVENTS_FILE=infra/storage/fixtures/delete-events.ndjson ./infra/storage/scripts/reconcile-deletes.sh
```
