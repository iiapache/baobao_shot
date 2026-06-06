# API 契约仓库

OpenAPI（REST，经网关对外）与 protobuf（gRPC，服务间）定义，对齐 [design-api.md](../docs/design-api.md)。

## 目录

```text
contracts/
├── openapi/
│   ├── openapi.yaml           # 入口（$ref 聚合分模块 paths）
│   ├── openapi.bundle.yaml    # CI / Swagger 用 bundle（脚本生成，勿手改）
│   ├── .spectral.yaml         # OpenAPI lint 规则
│   ├── components/common.yaml # 统一响应体、公共 schema
│   └── paths/                 # 按业务域拆分
│       ├── auth.yaml          # §3
│       ├── family.yaml        # §4.1
│       ├── baby.yaml          # §4.2
│       ├── uploads.yaml       # §5
│       ├── ai.yaml            # §6
│       ├── posts.yaml         # §7
│       ├── credits.yaml       # §8.1
│       ├── subscriptions.yaml # §8.2
│       ├── caption.yaml       # §9
│       ├── notifications.yaml # §10
│       └── backup.yaml        # §11
├── protobuf/
│   ├── buf.yaml / buf.gen.yaml
│   ├── Makefile
│   └── proto/baobao/          # gRPC service 占位
└── breaking-change/
    └── oasdiff.yaml           # breaking 检查说明
```

## design-api 章节覆盖

| design-api | OpenAPI 模块 | protobuf 占位 |
| --- | --- | --- |
| §3 鉴权与账号 | `paths/auth.yaml` | `auth/v1/auth_family.proto` |
| §4.1 家庭 | `paths/family.yaml` | `auth/v1/auth_family.proto` |
| §4.2 宝宝档案 | `paths/baby.yaml` | `auth/v1/auth_family.proto` |
| §5 媒体上传 | `paths/uploads.yaml` | `media/v1/media.proto` |
| §6 AI 任务 | `paths/ai.yaml` | `ai/v1/ai_dispatch.proto` |
| §7 家庭圈 | `paths/posts.yaml` | `feed/v1/feed.proto` |
| §8 积分 / 订阅 | `paths/credits.yaml`, `subscriptions.yaml` | `credit/v1/credit.proto` |
| §9 智能文案 | `paths/caption.yaml` | （caption-svc 为 Python，仅 REST） |
| §10 通知 | `paths/notifications.yaml` | `notification/v1/notification.proto` |
| §11 备份凭据 | `paths/backup.yaml` | `auth/v1/auth_family.proto` |
| §12 错误码 | `components/common.yaml` ErrorResponse | — |

> WebSocket `/v1/ws/ai` 不在 OpenAPI 3 覆盖范围，见 design-api §6.3。

## 本地 lint

```bash
# 依赖：Node.js（spectral + redocly）、buf（protobuf）
brew install bufbuild/buf/buf   # macOS

chmod +x scripts/contract-lint.sh
./scripts/contract-lint.sh              # lint
./scripts/contract-lint.sh --breaking   # lint + breaking change
```

## Breaking change 流程

1. **非破坏性变更**（默认）：仅新增可选字段 / 新端点 / 新 enum 值；OpenAPI `info.version` patch +1；MR 通过 `lint:contracts` 即可。
2. **破坏性变更**（删字段、改类型、删路径、改 path 参数名等）：
   - 优先升至 URI `v2`（design-api §13），保留 `v1` 至少 6 个月；
   - 若必须在 `v1` 内破坏，MR 描述须标注 **BREAKING**，通知 iOS / 各消费服务；
   - CI `lint:contracts:breaking` 会失败，需 reviewer 确认后按豁免流程合并（或改回兼容方案）。
3. **protobuf**：`buf breaking --against main`；仅可安全变更（新增 field number、新增 RPC）否则升 package minor/major。
4. **合并后**：在 main 上重新生成 `openapi.bundle.yaml` 并提交，作为下次 breaking 基线。

## 端侧 Swagger / Codegen 参考

```bash
# 生成 bundle（Spectral / oasdiff / Swagger UI 共用）
npx @redocly/cli bundle contracts/openapi/openapi.yaml \
  -o contracts/openapi/openapi.bundle.yaml

# Swagger UI（本地预览）
npx swagger-ui-watcher contracts/openapi/openapi.bundle.yaml

# Swift 模型参考（示例，正式接入见 iOS Network 包）
docker run --rm -v "$PWD:/local" openapitools/openapi-generator-cli generate \
  -i /local/contracts/openapi/openapi.bundle.yaml \
  -g swift5 -o /local/tmp/openapi-swift
```

## 与 tools/protobuf 关系

契约源文件在 `contracts/protobuf/`。`tools/protobuf/` 为兼容 T0.17 脚手架的薄封装，Makefile 委托至本目录。

## CI

GitLab job `lint:contracts`（Spectral + buf lint）；MR 额外跑 `lint:contracts:breaking`（oasdiff + buf breaking）。
