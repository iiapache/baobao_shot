# GitLab CI/CD 变量说明

> 在 GitLab **Settings → CI/CD → Variables** 中配置。禁止将真实密钥提交到仓库。

## 必需变量（生产）

| 变量 | 类型 | 说明 | 示例 |
| --- | --- | --- | --- |
| `CI_REGISTRY` | Variable | 容器镜像仓库地址 | `registry.cn-hangzhou.aliyuncs.com/baobao` |
| `CI_REGISTRY_USER` | Variable | 仓库登录用户名 | `ci-bot` |
| `CI_REGISTRY_PASSWORD` | Masked | 仓库登录密码 / Token | — |
| `CI_REGISTRY_IMAGE` | Variable | 镜像前缀（可选，默认 `$CI_REGISTRY/baobao`） | `registry.example.com/baobao` |

GitLab 内置 Container Registry 时，以下变量自动注入，无需手动配置：

- `CI_REGISTRY` — `registry.gitlab.com`
- `CI_REGISTRY_USER` / `CI_REGISTRY_PASSWORD` — job token
- `CI_REGISTRY_IMAGE` — `$CI_REGISTRY/$CI_PROJECT_PATH`

## 可选变量

| 变量 | 说明 | 默认 |
| --- | --- | --- |
| `DOCKER_PLATFORMS` | buildx 目标平台 | `linux/amd64` |
| `DOCKER_PUSH` | job 内是否 push（`true`/`false`） | `true` |
| `ARGOCD_SERVER` | ArgoCD API 地址 | — |
| `ARGOCD_AUTH_TOKEN` | ArgoCD Token（Masked） | — |

## ArgoCD 集成（deploy-staging）

deploy job 当前为 **manual + 占位**。启用自动部署时追加：

1. 在 GitLab 配置 `ARGOCD_SERVER`、`ARGOCD_AUTH_TOKEN`
2. deploy job 使用 `argoproj/argocd` 镜像执行 `argocd app sync`
3. 或采用 **GitOps**：CI 更新 `infra/k8s/clusters/*/staging-*-values.yaml` 中 `image.tag` 并 push，ArgoCD 自动同步

## iOS（macOS runner / Xcode Cloud）

| 变量 | 说明 |
| --- | --- |
| `MATCH_PASSWORD` | fastlane match 加密密码（Masked） |
| `APP_STORE_CONNECT_API_KEY` | ASC API Key JSON（File/Variable） |

MR 触发 `test:ios` 使用 Linux 占位；正式单测需 macOS runner 或 Xcode Cloud workflow。

## 本地验证 docker-build.sh

```bash
export DOCKER_PUSH=false
./infra/ci/docker-build.sh \
  --service hello \
  --context services/hello \
  --dockerfile services/hello/Dockerfile \
  --registry localhost:5000/baobao \
  --tag dev \
  --push false
```
