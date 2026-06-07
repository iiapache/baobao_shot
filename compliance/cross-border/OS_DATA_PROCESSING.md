# 海外区（OS）跨境数据处理合规

> **任务编号**：T7.4（P7）  
> **负责人**：COMP（合规法务）  
> **最后更新**：2026-06-06

## 1. 背景与目标

海外区（`region=os`）AI 能力依赖 OpenAI（GPT Image 2）与 Google Vertex（Nano Banana / Imagen）。根据 [PRD §6](../../docs/PRD.md) 与 [dev-plan T7.4](../../docs/dev-plan.md#101-子任务清单)：

1. 个人信息出境须签署**个人信息出境标准合同**（或等效合规路径）。
2. 调用 OpenAI / Google 须使用**标准合同端点**，并确认**不参与模型训练**。
3. CN 用户**绝不**路由至 OS 适配器（`ModelRouter` 硬隔离，design-backend §5.3）。

## 2. 标准合同 Checklist

| # | 检查项 | 责任方 | 状态 | 证据/备注 |
| --- | --- | --- | --- | --- |
| 1 | 与 OpenAI 签署 DPA / 企业协议，含数据不用于训练条款 | COMP + 法务 | ☐ 待签署 | 合同编号：____________ |
| 2 | 与 Google Cloud 签署 DPA，Vertex AI 数据不用于训练 | COMP + 法务 | ☐ 待签署 | 合同编号：____________ |
| 3 | 个人信息出境标准合同（网信办模板）与境外接收方清单 | COMP | ☐ 待备案 | 备案号：____________ |
| 4 | OS 版隐私政策披露境外接收方、处理目的、保留期限 | COMP + iOS | ☐ 待上线 | 链接：____________ |
| 5 | ai-dispatch-svc 仅部署于 `prod-os`（EKS 新加坡） | INFRA | ☑ 架构约束 | [k8s/namespaces](../../infra/k8s/namespaces/namespaces.yaml) |
| 6 | CN 集群 Vault policy 拒绝读取 OS AI 凭据 | INFRA | ☑ 策略约束 | [ai-dispatch-svc.hcl](../../infra/vault/policies/ai-dispatch-svc.hcl) |
| 7 | `compliance.os_training_opt_out=true`（config-svc OS 区） | BE | ☑ 已实现 | config-svc `memory.go` |
| 8 | 端点环境变量指向标准合同代理 URL | BE + INFRA | ☑ 已实现 | 见 §3 |
| 9 | 请求携带 no-training Header / 参数 | BE | ☑ stub 已实现 | 见 §4 |
| 10 | 季度复核：厂商条款变更、端点漂移 | COMP | ☐ 例行 | 下次复核：____________ |

## 3. 合规端点清单

| 厂商 | Adapter | 环境变量（主） | 环境变量（兼容） | 默认端点 | 说明 |
| --- | --- | --- | --- | --- | --- |
| OpenAI | `GptImage2Adapter` | `OPENAI_API_BASE` | `OPENAI_BASE_URL` | `https://api.openai.com/v1` | prod-os 须替换为合同代理 URL |
| Google Vertex | `NanoBananaAdapter` | `GOOGLE_API_BASE` | `GOOGLE_ENDPOINT` | `https://aiplatform.googleapis.com` | prod-os 须替换为新加坡区域合同代理 |

**Vault 路径**（prod-os）：

- `secret/data/prod-os/os/ai-dispatch/openai`
- `secret/data/prod-os/os/ai-dispatch/google`

**模板**：[infra/vault/secrets-template/ai-dispatch.env.example](../../infra/vault/secrets-template/ai-dispatch.env.example)

### 3.1 路由隔离

```
CN 用户 (X-Region: cn)
  → ModelRouter 仅候选 RegionCN 适配器
  → Seedream / 通义万相 / 即梦 / Seedance
  → 绝不调用 OpenAI / Google

OS 用户 (X-Region: os)
  → ModelRouter 仅候选 RegionOS 适配器
  → GptImage2 / NanoBanana
  → 走 §3 合规端点 + §4 no-training 标记
```

## 4. 不参与训练确认

### 4.1 OpenAI

| 项 | 值 |
| --- | --- |
| Header 名称 | `OpenAI-Data-Collection-Opt-Out` |
| Header 值 | `true` |
| 环境变量开关 | `OPENAI_NO_TRAINING_HEADER=1` |
| config-svc 开关 | `compliance.os_training_opt_out=true`（OS 区） |
| Organization 设置 | 控制台启用 Zero Data Retention / opt-out（须人工确认） |

> **Stub 说明**：Header 名称与值按 OpenAI Enterprise DPA 约定占位；上线前须对照当期 API 文档与合同附件复核。

### 4.2 Google Vertex AI

| 项 | 值 |
| --- | --- |
| Header 名称 | `X-Vertex-AI-Data-Usage` |
| Header 值 | `no-training` |
| 环境变量开关 | `GOOGLE_NO_TRAINING_HEADER=1` |
| config-svc 开关 | 同上 `compliance.os_training_opt_out` |
| 合同条款 | Vertex AI 数据不用于训练（须人工确认） |

> **Stub 说明**：Header 按 Vertex 企业合规文档占位；实际上线前须与 Google 客户经理确认最终参数名。

### 4.3 代码落点

| 组件 | 文件 |
| --- | --- |
| OS 配置加载 | `services/ai-dispatch-svc/internal/adapter/osconfig/config.go` |
| OpenAI Header | `services/ai-dispatch-svc/internal/adapter/gptimage2/client.go` |
| Google Header | `services/ai-dispatch-svc/internal/adapter/nanobanana/client.go` |
| CN/OS 路由隔离 | `services/ai-dispatch-svc/internal/router/router.go` |
| config-svc 开关 | `services/config-svc/internal/store/memory.go` |

## 5. 不参与训练确认记录模板

每次与厂商确认后，由 COMP 填写并归档至 `compliance/cross-border/records/`（目录按需创建）。

```markdown
# 不参与训练端点确认记录

| 字段 | 内容 |
| --- | --- |
| 记录编号 | OS-DPA-YYYY-MM-DD-NN |
| 确认日期 | YYYY-MM-DD |
| 确认人 | 姓名 / 职务 |
| 厂商 | OpenAI / Google |
| 合同/协议编号 | |
| 适用 Organization / GCP Project | |
| 合规端点 URL | |
| 不参与训练机制 | Header / Org 设置 / ZDR / 其他 |
| Header/参数名与值 | |
| 验证方式 | 单测 / staging 抓包 / 厂商书面回执 |
| 验证人 | |
| 下次复核日期 | YYYY-MM-DD |
| 附件 | 邮件截图 / 合同页码 / API 文档链接 |

## 确认结论

- [ ] 已确认该端点下 API 调用数据不用于训练
- [ ] 已确认与个人信息出境标准合同接收方一致
- [ ] 已更新 Vault 端点与环境变量

## 变更记录

| 日期 | 变更 | 操作人 |
| --- | --- | --- |
| | 初版确认 | |
```

## 6. 验证

```bash
# ai-dispatch-svc 合规单测
cd services/ai-dispatch-svc
go test ./internal/adapter/osconfig/... ./internal/router/... -count=1

# config-svc OS 开关
cd services/config-svc
go test ./internal/handler/rest/... -run OSTraining -count=1
```

**验收标准（T7.4）**：

- [x] 海外区调用走标准合同端点（`OPENAI_API_BASE` / `GOOGLE_API_BASE` 可配置）
- [x] OpenAI/Google 不参与训练端点确认（Header stub + 确认记录模板）
- [x] CN 用户绝不路由 OS（`TestModelRouter_CNNeverRoutesToOS`）
- [x] config-svc `compliance.os_training_opt_out=true`（OS 区）
- [x] 单测 ≥ 5（osconfig + router + config-svc）
