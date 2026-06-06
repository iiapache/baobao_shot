# P0 完成集成检查报告

> **检查日期**：2026-06-06  
> **判定依据**：[dev-plan.md §3.3](./dev-plan.md#33-p0-并行批次每批--5) — 批 P0-4 全部完成 + 端侧空壳调通 mock 登录冒烟  
> **M1 质量门**：[dev-plan.md §12](./dev-plan.md#12-关键里程碑与质量门) — 基础设施就绪（W2 末）

---

## 1. 执行摘要

| 项 | 结果 |
| --- | --- |
| `scripts/p0-smoke.sh` | **PASS**（35 PASS / 0 FAIL / 0 SKIP） |
| `tests/smoke/smoke.sh`（Mock API 端到端） | **未执行**（本机无 Docker） |
| iOS mock 登录单测（BabyCameraNetwork） | **未执行**（本机未配置 Xcode，`xcodebuild` 不可用） |
| **M1 是否达标** | **否** — 本地聚合脚本通过，但 mock 登录冒烟未在本环境跑通；集群 / Xcode 依赖项均未验证 |

---

## 2. T0.x 任务产出物索引

### 批 P0-1（T0.1 / T0.3 / T0.9 / T0.10 / T0.12）

| 任务 | 主要产出 | 路径索引 |
| --- | --- | --- |
| T0.1 | Monorepo 骨架、分支策略、CODEOWNERS、PR 模板 | [`README.md`](../README.md)、[`CONTRIBUTING.md`](../CONTRIBUTING.md)、[`CODEOWNERS`](../CODEOWNERS)、[`.github/PULL_REQUEST_TEMPLATE.md`](../.github/PULL_REQUEST_TEMPLATE.md)、[`.gitlab/merge_request_templates/Default.md`](../.gitlab/merge_request_templates/Default.md)、[`infra/docs/branch-protection.md`](../infra/docs/branch-protection.md) |
| T0.3 | K8s 双集群 Helm / 命名空间 / hello chart | [`infra/k8s/`](../infra/k8s/)、[`infra/k8s/namespaces/`](../infra/k8s/namespaces/)、[`infra/k8s/charts/hello/`](../infra/k8s/charts/hello/)、[`infra/k8s/clusters/`](../infra/k8s/clusters/) |
| T0.9 | 算法 / 深度合成备案跟踪 | [`compliance/algorithm-filing/`](../compliance/algorithm-filing/)、[`MODEL_FILING_TRACKER.md`](../compliance/algorithm-filing/MODEL_FILING_TRACKER.md)、[`WEEKLY_STATUS_TEMPLATE.md`](../compliance/algorithm-filing/WEEKLY_STATUS_TEMPLATE.md) |
| T0.10 | ICP 备案跟踪 | [`compliance/icp-filing/`](../compliance/icp-filing/)、[`ICP_FILING_TRACKER.md`](../compliance/icp-filing/ICP_FILING_TRACKER.md) |
| T0.12 | 第三方账号清单 + Vault 模板 | [`infra/accounts/THIRD_PARTY_ACCOUNTS.md`](../infra/accounts/THIRD_PARTY_ACCOUNTS.md)、[`infra/accounts/verification-checklist.md`](../infra/accounts/verification-checklist.md)、[`infra/vault/secrets-template/`](../infra/vault/secrets-template/) |

### 批 P0-2（T0.2 / T0.4 / T0.5 / T0.6 / T0.13）

| 任务 | 主要产出 | 路径索引 |
| --- | --- | --- |
| T0.2 | GitLab CI、ArgoCD、Docker 构建、fastlane | [`.gitlab-ci.yml`](../.gitlab-ci.yml)、[`infra/ci/`](../infra/ci/)、[`infra/argocd/`](../infra/argocd/)、[`ios/fastlane/`](../ios/fastlane/) |
| T0.4 | PostgreSQL / MongoDB / Redis 双区模板 | [`infra/data/`](../infra/data/)、[`infra/data/postgresql/`](../infra/data/postgresql/)、[`infra/data/mongodb/`](../infra/data/mongodb/)、[`infra/data/redis/`](../infra/data/redis/)、[`infra/data/scripts/connectivity-test.sh`](../infra/data/scripts/connectivity-test.sh) |
| T0.5 | Kafka topic + OSS/S3 生命周期 | [`infra/messaging/`](../infra/messaging/)、[`infra/messaging/kafka/topics.yaml`](../infra/messaging/kafka/topics.yaml)、[`infra/storage/`](../infra/storage/)、[`infra/messaging/scripts/produce-consume-test.sh`](../infra/messaging/scripts/produce-consume-test.sh) |
| T0.6 | APISIX 网关 chart + 路由 + TLS | [`infra/gateway/`](../infra/gateway/)、[`infra/gateway/charts/baobao-gateway/`](../infra/gateway/charts/baobao-gateway/)、[`infra/gateway/scripts/health-check.sh`](../infra/gateway/scripts/health-check.sh) |
| T0.13 | iOS 工程脚手架（SPM 包结构） | [`ios/BabyCamera.xcodeproj`](../ios/BabyCamera.xcodeproj)、[`ios/BabyCamera/`](../ios/BabyCamera/)、[`ios/Packages/`](../ios/Packages/)、[`ios/README.md`](../ios/README.md) |

### 批 P0-3（T0.7 / T0.8 / T0.11 / T0.14 / T0.17）

| 任务 | 主要产出 | 路径索引 |
| --- | --- | --- |
| T0.7 | Vault Helm / Injector / 轮换 SOP | [`infra/vault/`](../infra/vault/)、[`infra/vault/rotation/SOP.md`](../infra/vault/rotation/SOP.md)、[`infra/vault/sealed-secrets/`](../infra/vault/sealed-secrets/) |
| T0.8 | Prometheus / Grafana / Loki / Tempo / Sentry 基线 | [`infra/observability/`](../infra/observability/)、[`infra/observability/grafana/dashboards/`](../infra/observability/grafana/dashboards/)、[`infra/observability/scripts/deploy-dev.sh`](../infra/observability/scripts/deploy-dev.sh) |
| T0.11 | 字体 / 贴纸 / 模板资源包 + 采购跟踪 | [`design-assets/`](../design-assets/)、[`design-assets/PROCUREMENT_TRACKER.md`](../design-assets/PROCUREMENT_TRACKER.md)、[`design-assets/templates/manifest.json`](../design-assets/templates/manifest.json) |
| T0.14 | DesignSystem + Catalog | [`ios/Packages/DesignSystem/`](../ios/Packages/DesignSystem/)、[`DesignSystemCatalogView.swift`](../ios/Packages/DesignSystem/Sources/DesignSystem/Catalog/DesignSystemCatalogView.swift) |
| T0.17 | Go / Python 服务模板 + hello | [`services/_template/`](../services/_template/)、[`services/hello/`](../services/hello/)、[`tools/protobuf/`](../tools/protobuf/) |

### 批 P0-4（T0.15 / T0.16 / T0.18 / T0.19 / T0.20）

| 任务 | 主要产出 | 路径索引 |
| --- | --- | --- |
| T0.15 | Network 包 + Mock + 单测 | [`ios/Packages/BabyCameraNetwork/`](../ios/Packages/BabyCameraNetwork/)、[`MockURLProtocol.swift`](../ios/Packages/BabyCameraNetwork/Sources/BabyCameraNetwork/Mock/MockURLProtocol.swift)、[`BabyCameraNetworkTests.swift`](../ios/Packages/BabyCameraNetwork/Tests/BabyCameraNetworkTests/BabyCameraNetworkTests.swift) |
| T0.16 | GRDB migration + Repository 骨架 | [`ios/Packages/Database/`](../ios/Packages/Database/)、[`DatabaseMigrator.swift`](../ios/Packages/Database/Sources/Database/Migrations/DatabaseMigrator.swift)、[`MigrationTests.swift`](../ios/Packages/Database/Tests/DatabaseTests/MigrationTests.swift) |
| T0.18 | OpenAPI + protobuf 契约 + CI lint | [`contracts/`](../contracts/)、[`scripts/contract-lint.sh`](../scripts/contract-lint.sh) |
| T0.19 | config-svc 雏形 + Feature Flag | [`services/config-svc/`](../services/config-svc/)、[`infra/feature-flags/`](../infra/feature-flags/)、[`golden_hashes.json`](../infra/feature-flags/golden_hashes.json) |
| T0.20 | QA 测试基础设施 | [`tests/`](../tests/)、[`tests/mocks/`](../tests/mocks/)、[`tests/smoke/smoke.sh`](../tests/smoke/smoke.sh)、[`tests/accounts/test-accounts.yaml`](../tests/accounts/test-accounts.yaml)、[`tests/staging/README.md`](../tests/staging/README.md)、[`tests/performance/device-matrix.md`](../tests/performance/device-matrix.md) |

---

## 3. P0 质量门自检表（M1 里程碑）

> M1 退出标准：**P0 批 1–4 完成；mock 登录冒烟通过**（[dev-plan §12](./dev-plan.md#12-关键里程碑与质量门)）

| # | 检查项 | 标准 | 自检结果 | 证据 |
| --- | --- | --- | :---: | --- |
| G1 | P0 批 P0-1 产出物齐备 | T0.1/3/9/10/12 目录与文档存在 | ✅ | §2 批 P0-1 索引；`p0-smoke.sh` 目录检查 PASS |
| G2 | P0 批 P0-2 产出物齐备 | T0.2/4/5/6/13 模板可引用 | ✅ | §2 批 P0-2 索引 |
| G3 | P0 批 P0-3 产出物齐备 | T0.7/8/11/14/17 模板可引用 | ✅ | §2 批 P0-3 索引 |
| G4 | P0 批 P0-4 产出物齐备 | T0.15–20 代码 / 契约 / QA 骨架 | ✅ | §2 批 P0-4 索引 |
| G5 | Go 服务单测 | `hello` + `_template/go` 通过 | ✅ | `go test ./...` — hello 1 pkg、template 2 pkg ok |
| G6 | 契约 lint | OpenAPI Spectral + buf lint | ✅ | `contract-lint.sh` PASS（需本机 `buf`） |
| G7 | infra 脚本语法 | 5 个 shell 脚本 `bash -n` | ✅ | deploy-dev / health-check / produce-consume / connectivity / docker-build |
| G8 | config-svc 单测 | Feature flag 评估 + REST handler | ✅ | `services/config-svc` — `go test ./...` 13 passed（独立验证） |
| G9 | **Mock 登录冒烟（HTTP）** | `tests/smoke/smoke.sh` 登录→上传→发布 | ❌ | 未执行：本机 `docker` 不可用，无法启动 `tests/mocks` |
| G10 | **Mock 登录冒烟（iOS）** | BabyCameraNetwork mock 登录 + 401 刷新 + 脱敏 | ❌ | 未执行：`xcodebuild` 需完整 Xcode（当前仅 CLT） |
| G11 | iOS 空壳可编译 | `xcodebuild -showBuildSettings` / 模拟器 build | ❌ | 未验证：同上 |
| G12 | K8s 双集群可部署 hello | `kubectl get ns` + 网关访问 hello | ❌ | 未验证：无集群 kubeconfig |
| G13 | 数据层连通性 | PG/Mongo/Redis 端到端 | ❌ | 未验证：需 docker compose 或 K8s |
| G14 | Kafka / OSS 可收发 | topic 生产消费 + 桶策略 | ❌ | 未验证：需集群 / 云账号 |
| G15 | GitLab CI 全绿 | push 触发 lint/test/build | ⚠️ | 未在本报告环境触发；本地子集已通过 |
| G16 | dev-plan 状态表 | P0-4 五项 + P0-SMOKE 为 done | ⚠️ | 状态表仍标记 T0.19/T0.20/P0-SMOKE 为 in-progress（本报告不修改状态表） |

**M1 综合判定**：**未达标**（G9/G10 为 M1 硬门槛，当前环境未通过；G11–G14 为集群依赖未验证项）

---

## 4. `scripts/p0-smoke.sh` 执行记录

### 4.1 脚本说明

聚合验证项：

1. `go test` — `services/hello`、`services/_template/go`
2. `./scripts/contract-lint.sh`
3. `bash -n` — `infra/observability/scripts/deploy-dev.sh`、`infra/gateway/scripts/health-check.sh`、`infra/messaging/scripts/produce-consume-test.sh`、`infra/data/scripts/connectivity-test.sh`、`infra/ci/docker-build.sh`
4. 关键目录存在性（25 项）
5. P0-4 增强检查：`services/config-svc`、`tests/{mocks,e2e,integration}` 任一存在

### 4.2 第一次运行（2026-06-06，buf 未安装）

```
汇总: PASS=33 FAIL=1 SKIP=1
失败项: contract-lint — error: buf 未安装
跳过项: T0.20 tests 子目录（首次运行时 mocks 目录检测逻辑）
退出码: 1
```

### 4.3 第二次运行（安装 `buf` 后，最终结果）

```
>>> go test services/hello                          [PASS]
>>> go test services/_template/go                     [PASS]
>>> contract-lint (Spectral + buf lint)               [PASS]
>>> bash -n infra/* scripts (5)                       [PASS]
>>> dir exists (25)                                   [PASS]
>>> T0.19 services/config-svc                         [PASS]
>>> T0.20 tests 子目录 (tests/mocks)                  [PASS]

汇总: PASS=35 FAIL=0 SKIP=0
退出码: 0
```

### 4.4 环境前置

| 工具 | 第一次 | 第二次 | 说明 |
| --- | :---: | :---: | --- |
| Go | ✅ | ✅ | 1.22+ |
| Node/npx | ✅ | ✅ | Spectral / Redocly bundle |
| buf | ❌ | ✅ | 契约 lint 硬依赖；CI 镜像应预装 |
| Docker | ❌ | ❌ | E2E mock 冒烟未覆盖 |
| Xcode | ❌ | ❌ | iOS 单测 / build 未覆盖 |

---

## 5. 未验证项清单（需 Xcode / 集群环境）

### 5.1 需 Xcode / macOS 完整工具链

| 项 | 命令 / 步骤 | 关联任务 |
| --- | --- | --- |
| iOS 工程构建设置 | `cd ios && xcodebuild -project BabyCamera.xcodeproj -scheme BabyCamera -showBuildSettings` | T0.13 |
| iOS 模拟器 build | `xcodebuild … -destination 'platform=iOS Simulator,name=iPhone 16' build` | T0.13 |
| Network mock 登录单测 | `xcodebuild test` 或 `swift test` in `BabyCameraNetwork` | T0.15 |
| Database migration 单测 | `MigrationTests` in `Database` package | T0.16 |
| DesignSystem Catalog 目视 | 运行 Catalog 预览页 | T0.14 |
| fastlane 本地 lane | `cd ios && bundle exec fastlane …` | T0.2 |

### 5.2 需 Docker / 本地 compose

| 项 | 命令 / 步骤 | 关联任务 |
| --- | --- | --- |
| Mock API 冒烟 | `cd tests/mocks && docker compose up -d mock-api && cd ../smoke && ./smoke.sh` | T0.20 / P0-SMOKE |
| 数据层连通性 | `cd infra/data && docker compose -f docker-compose.dev.yml up -d && ./scripts/connectivity-test.sh` | T0.4 |
| Kafka 生产消费 | `infra/messaging/scripts/produce-consume-test.sh` | T0.5 |
| Unleash 可选栈 | `cd infra/feature-flags && docker compose up -d` | T0.19 |

### 5.3 需 K8s 双集群（ACK + EKS）

| 项 | 命令 / 步骤 | 关联任务 |
| --- | --- | --- |
| 命名空间创建 | `kubectl apply -f infra/k8s/namespaces/namespaces.yaml` | T0.3 |
| hello 经网关访问 | 部署 hello + APISIX，`infra/gateway/scripts/health-check.sh` | T0.3 / T0.6 |
| ArgoCD 同步 | `infra/argocd` Application 部署 staging | T0.2 |
| Vault 取密 | 服务从 Vault 读取 DB 密码 / API Key | T0.7 |
| 监控看板 | Prometheus scrape + Grafana dashboard 可见指标 | T0.8 |
| Observability 栈 | `infra/observability/scripts/deploy-dev.sh` | T0.8 |

### 5.4 需云账号 / 外部服务（非 P0 阻塞但 M1 后需跟进）

| 项 | 说明 | 关联任务 |
| --- | --- | --- |
| 备案号回填 | 算法 / ICP 仍为「已受理」，无正式备案号 | T0.9 / T0.10 |
| 字体贴纸正式授权 | `design-assets/PROCUREMENT_TRACKER.md` 多数为「待采购」 | T0.11 |
| 第三方账号实连 | `infra/accounts/verification-checklist.md` 需逐项勾选 | T0.12 |
| GitLab CI 远端流水线 | push 触发镜像构建 + iOS MR 单测 | T0.2 |

---

## 6. 建议下一步（退出 M1）

1. **本机 / CI 安装 `buf`**，确保 `contract-lint.sh` 在无人工干预下通过（已在第二次 smoke 验证）。
2. **启动 Docker**，执行 `tests/mocks` + `tests/smoke/smoke.sh`，完成 HTTP mock 登录冒烟。
3. **配置 Xcode 16+**，跑通 `BabyCameraNetworkTests`（mock 登录 / 401 刷新 / 日志脱敏）及 `xcodebuild build`。
4. **staging 集群**部署 hello + 网关，执行 `health-check.sh` / `connectivity-test.sh`。
5. 集成检查通过后，由编排 agent 更新 dev-plan 状态表（T0.19 / T0.20 / P0-SMOKE → done）。

---

## 7. 附录：相关脚本

| 脚本 | 用途 |
| --- | --- |
| [`scripts/p0-smoke.sh`](../scripts/p0-smoke.sh) | P0 本地聚合验证（本报告主证据） |
| [`scripts/contract-lint.sh`](../scripts/contract-lint.sh) | OpenAPI + protobuf lint |
| [`tests/smoke/smoke.sh`](../tests/smoke/smoke.sh) | 登录 → 拍照 mock → 发布 mock（需 mock-api） |
