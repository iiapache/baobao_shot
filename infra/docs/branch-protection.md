# main 分支保护配置说明

> 任务 T0.1 产出。在 GitLab 项目创建后由 Maintainer 执行一次性配置。

## 目标

- `main` 仅通过 Merge Request 合并
- CI pipeline 必须全部通过才可合并
- 关键路径变更须 CODEOWNERS 批准

## GitLab 配置步骤

### 1. 保护 main 分支

路径：**Settings → Repository → Protected branches → Protect a branch**

| 字段 | 配置 |
| --- | --- |
| Branch | `main` |
| Allowed to merge | `Maintainers` 或 `Developers + Maintainers` |
| Allowed to push and merge | `No one`（禁止直接 push） |
| Allowed to force push | ❌ 关闭 |
| Code owner approval | ✅ 开启 |

### 2. 合并请求设置

路径：**Settings → Merge requests**

| 字段 | 配置 |
| --- | --- |
| Merge method | Squash commit（推荐） |
| Pipelines must succeed | ✅ 开启 |
| All threads must be resolved | ✅ 开启 |
| Merge checks → Pipelines must succeed | ✅ |

### 3. CI 必过 job

以下 job 在 `.gitlab-ci.yml` 中标记为必过（`allow_failure: false`，默认）：

| Stage | Job | 说明 |
| --- | --- | --- |
| `lint` | `lint:repo` | 仓库结构、文档链接检查 |
| `lint` | `lint:contracts` | OpenAPI / proto lint（T0.18 后启用） |
| `test` | `test:services` | 后端单测占位 |
| `test` | `test:ios` | iOS 单测占位（T0.13 后启用） |
| `build` | `build:services` | 服务构建占位 |
| `build` | `build:ios` | iOS 构建占位（T0.13 后启用） |

> T0.2 将补充镜像构建与 ArgoCD 部署 stage。

### 4. CODEOWNERS 集成

1. 确保根目录 `CODEOWNERS` 已提交。
2. GitLab **Settings → General → Merge request approvals**：
   - ✅ Prevent approval by author
   - ✅ Prevent committers from approving
   - ✅ Require approval from code owners（若 Premium 可用）

团队占位符（`@ios-team` 等）需在 GitLab 中创建对应 Group 或替换为实际 `@username`。

## 验收自检

| 验收项 | 状态 | 验证方式 |
| --- | --- | --- |
| main 分支保护说明文档 | ✅ | 本文档 |
| 必过 CI 配置骨架 | ✅ | `.gitlab-ci.yml` lint/test/build stages |
| PR 模板含「关联设计章节」 | ✅ | `.gitlab/merge_request_templates/Default.md` |
| Conventional Commits 规范 | ✅ | `CONTRIBUTING.md` |
| monorepo 目录结构 | ✅ | `ios/` `services/` `contracts/` `infra/` `tests/` |

## 回滚

若误配保护规则：

1. **Settings → Repository → Protected branches** 编辑或取消保护。
2. 恢复后直接 push 仅用于紧急修复，事后须补 MR 记录。
