# 贡献指南

本文档说明宝宝成长相机 monorepo 的分支策略、提交规范与合并流程。

## 仓库结构

```text
baobao/
├── ios/           # iOS 端工程（design-ios §3）
├── services/      # 后端微服务（design-backend §3）
├── contracts/     # OpenAPI / protobuf 契约
├── infra/         # K8s、Helm、CI/CD
├── tests/         # QA 集成 / E2E
└── docs/          # 产品与设计文档
```

## 分支策略

### 长期分支

| 分支 | 用途 | 保护级别 |
| --- | --- | --- |
| `main` | 生产就绪代码，仅通过 MR 合并 | **受保护** |
| `staging` | 预发布集成（可选，T0.2 后启用） | 受保护 |

### 短期分支

从 `main` 拉取，命名规范：

```text
feature/<任务编号>-<简短描述>   # 例：feature/T1.3-auth-family-svc
fix/<任务编号>-<简短描述>
chore/<任务编号>-<简短描述>
```

规则：

1. **禁止**直接向 `main` push（除紧急 hotfix 流程，需 INFRA 审批）。
2. 每个 MR/PR 对应一个可独立验收的子任务（见 `docs/dev-plan.md`）。
3. MR 合并前须通过 CI 全部必过 job（见 `.gitlab-ci.yml`）。
4. 至少 1 名 CODEOWNERS 指定 reviewer 批准。

### main 分支保护（GitLab 配置）

在 GitLab **Settings → Repository → Protected branches** 中配置 `main`：

| 配置项 | 值 | 说明 |
| --- | --- | --- |
| Allowed to merge | Maintainers + Developers（经 MR） | 禁止直接 push |
| Allowed to push | No one | 强制走 MR |
| Require approval | ≥ 1 | CODEOWNERS 自动指派 |
| Pipelines must succeed | ✅ | CI 全绿才可合并 |
| All threads resolved | ✅ | 评审意见须关闭 |
| Require CODEOWNERS approval | ✅ | 路径级 owner 须批准 |

详细操作步骤见 [infra/docs/branch-protection.md](infra/docs/branch-protection.md)。

## Conventional Commits

所有 commit message 遵循 [Conventional Commits 1.0](https://www.conventionalcommits.org/zh-hans/v1.0.0/)。

### 格式

```text
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

### type

| type | 用途 |
| --- | --- |
| `feat` | 新功能 |
| `fix` | 缺陷修复 |
| `docs` | 仅文档变更 |
| `style` | 格式（不影响逻辑） |
| `refactor` | 重构 |
| `perf` | 性能优化 |
| `test` | 测试 |
| `chore` | 构建、CI、依赖 |
| `revert` | 回滚 |

### scope（推荐）

与 monorepo 目录对齐，例如：

- `ios`、`services/auth-family-svc`、`contracts`、`infra`、`tests`

### 示例

```text
feat(services/auth-family-svc): add JWT refresh endpoint

fix(ios): prevent camera session leak on background

docs(contracts): update OpenAPI for feed publish API

chore(infra): add GitLab CI lint stage skeleton
```

### 关联任务

在 body 或 footer 中注明任务编号：

```text
feat(ios): add GRDB migration framework

Task: T0.16
Design: design-ios §5
```

## 合并请求（MR）流程

1. 从 `main` 创建 `feature/*` 分支。
2. 按 Conventional Commits 提交。
3. 推送并创建 MR，使用 `.gitlab/merge_request_templates/Default.md` 模板。
4. **必填「关联设计章节」**，便于评审追溯。
5. 等待 CI 通过 + CODEOWNERS 批准。
6. Squash merge 到 `main`（保持主干历史整洁）。

## 安全

- **禁止**提交 `.env`、密钥、证书、真实用户数据。
- 凭据统一走 HashiCorp Vault（见 T0.7）。
- MR 中若涉及 API 契约破坏性变更，须在 `contracts/` 目录标注并通知消费方。

## 参考

- [docs/dev-plan.md](docs/dev-plan.md) — 任务清单与验收标准
- [design-ios.md](docs/design-ios.md) — iOS 工程结构
- [design-backend.md](docs/design-backend.md) — 服务划分
