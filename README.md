# 宝宝成长相机（baobao）

宝宝成长相机 V1.0 monorepo — iOS 端 + 后端微服务 + API 契约 + 基础设施。

## 仓库结构

```text
baobao/
├── ios/              # iOS 端（Swift / SPM，design-ios §3）
├── services/         # 后端微服务（Go + Python，design-backend §3）
│   └── _template/    # 服务脚手架模板
├── contracts/        # OpenAPI + protobuf 契约
├── infra/            # K8s、Helm、ArgoCD、CI 配置
├── tests/            # QA 集成 / E2E / Mock
└── docs/             # PRD、设计文档、开发计划
```

## 设计文档

| 文档 | 说明 |
| --- | --- |
| [docs/PRD.md](docs/PRD.md) | 产品需求 |
| [docs/design.md](docs/design.md) | 总体设计 |
| [docs/design-ios.md](docs/design-ios.md) | iOS 端详设 |
| [docs/design-backend.md](docs/design-backend.md) | 后端详设 |
| [docs/design-api.md](docs/design-api.md) | API 契约详设 |
| [docs/dev-plan.md](docs/dev-plan.md) | 开发实施计划 |

## 快速开始

### 前置要求

- Git
- （后续）Xcode 15+、Go 1.22+、Docker、kubectl

### 克隆与分支

```bash
git clone <repo-url> baobao
cd baobao
git checkout -b feature/T0.x-your-task main
```

### 贡献流程

1. 阅读 [CONTRIBUTING.md](CONTRIBUTING.md) — 分支策略与 Conventional Commits
2. 创建 MR 时使用 `.gitlab/merge_request_templates/Default.md`
3. **必填「关联设计章节」** 字段
4. 等待 CI 通过 + CODEOWNERS 批准

### CI

Push 或 MR 触发 GitLab CI，阶段：`lint` → `test` → `build`。

```bash
# 本地快速自检（等价于 lint:repo）
test -d ios && test -d services && test -d contracts && test -d infra && test -d tests
```

### 分支保护

`main` 分支受保护，配置说明见 [infra/docs/branch-protection.md](infra/docs/branch-protection.md)。

## 后端服务（规划）

| 服务 | 目录 |
| --- | --- |
| auth-family-svc | `services/auth-family-svc/` |
| feed-svc | `services/feed-svc/` |
| media-svc | `services/media-svc/` |
| ai-dispatch-svc | `services/ai-dispatch-svc/` |
| audit-svc | `services/audit-svc/` |
| credit-sub-ad-svc | `services/credit-sub-ad-svc/` |
| caption-svc | `services/caption-svc/` |
| notification-svc | `services/notification-svc/` |
| config-svc | `services/config-svc/` |
| iap-callback-svc | `services/iap-callback-svc/` |

> 各服务目录将在对应开发任务中创建；当前仅有 `_template/` 占位。

## License

Proprietary — 内部项目，未经授权禁止分发。
