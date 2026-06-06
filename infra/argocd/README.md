# ArgoCD 蓝绿 / 渐进发布

与 `infra/k8s/argocd/applications/` 单服务 Application 互补：本目录提供 **ApplicationSet**、蓝绿 values 覆盖与发布策略说明。

## 目录结构

```text
infra/argocd/
├── README.md
├── applicationsets/
│   └── baobao-staging.yaml      # 多服务 staging ApplicationSet
└── values/
    └── blue-green-hello.yaml    # hello 蓝绿 Helm values 覆盖
```

## 与 k8s/argocd 的关系

| 路径 | 用途 |
| --- | --- |
| `infra/k8s/argocd/applications/` | 单服务 Application（dev/staging，已就绪） |
| `infra/argocd/applicationsets/` | 批量生成 Application、多集群 staging |
| `infra/argocd/values/` | 蓝绿 / Rollout 专用 Helm values 覆盖 |

部署顺序：

1. 先 `kubectl apply -f infra/k8s/argocd/applications/` 验证 hello
2. 再 `kubectl apply -f infra/argocd/applicationsets/` 启用 ApplicationSet

## 蓝绿发布策略

当前 hello chart 使用标准 `Deployment`。生产蓝绿有两条路径：

### 路径 A：Argo Rollouts（推荐，P7 T7.11 演练）

1. 安装 [Argo Rollouts](https://argoproj.github.io/argo-rollouts/) controller
2. 将 Deployment 替换为 Rollout，strategy 设为 `blueGreen`：

```yaml
strategy:
  blueGreen:
    activeService: hello-active
    previewService: hello-preview
    autoPromotionEnabled: false   # 手动切流量
    scaleDownDelaySeconds: 30
```

3. ArgoCD 同步 Rollout 资源；预览 Service 验证后 `kubectl argo rollouts promote hello`

### 路径 B：双 Deployment + Service 切换（无需 Rollouts）

1. 部署 `hello-blue` / `hello-green` 两个 Deployment
2. Service selector 指向 active 版本 label
3. 切换：更新 Service `selector.version` 从 blue → green
4. 网关（Kong/APISIX，T0.6）可按权重做 5% → 25% → 100% 灰度

`values/blue-green-hello.yaml` 为路径 B 的 Helm values 占位注释。

## 渐进发布（Canary）

- **网关层**：Kong/APISIX 按 header / 权重路由（T0.6）
- **Argo Rollouts Canary**：`steps: [5%, 25%, 100%]` + analysis template
- **App Store**：Phased Release（T7.14，端侧）

## ApplicationSet 用法

```bash
# 替换 baobao-staging.yaml 中 repoURL 后
kubectl apply -f infra/argocd/applicationsets/baobao-staging.yaml

argocd appset list
argocd app list -l baobao.io/environment=staging
```

ApplicationSet 会为 `clusters/ack-cn`、`clusters/eks-os` 各生成 staging hello Application。

## GitLab CI 联动

1. `docker:hello` push 镜像 → tag = `$CI_COMMIT_SHORT_SHA`
2. CI 更新 `infra/k8s/clusters/*/staging-hello-values.yaml` 中 `image.tag`（GitOps）
3. ArgoCD 检测 Git 变更 → sync → 新 Pod 就绪
4. 蓝绿：先 sync 到 preview，验证后 promote（Rollouts）或切 Service selector

详见 [infra/ci/README.md](../ci/README.md)。

## 验收自检

| 项 | 检查 | 预期 |
| --- | --- | --- |
| ApplicationSet | `kubectl apply --dry-run=client -f applicationsets/` | YAML 合法 |
| 蓝绿 values | `infra/argocd/values/blue-green-hello.yaml` | 注释与字段占位完整 |
| 与 CI 集成 | deploy-staging job 引用本目录 | job 脚本 test -f 通过 |
