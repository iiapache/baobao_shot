# ICP 备案跟踪表

> **任务**：T0.10（启动 + 受理跟踪）→ T7.2（备案号正式回填）  
> **更新频率**：受理前每周一；受理后每两周直至通过  
> **关联**：[SUBJECT_VERIFICATION.md](./SUBJECT_VERIFICATION.md)、[APP_STORE_METADATA_PLACEHOLDER.md](./APP_STORE_METADATA_PLACEHOLDER.md)

---

## 1. 备案概览

| 项 | 内容 |
| --- | --- |
| 产品名称（PRD） | 宝宝成长相机 |
| **备案 App 名称**（须与 App Store 一致） | **宝宝成长相机** |
| App Store Connect 名称（锁定） | 宝宝成长相机 |
| Bundle ID（规划） | `app.babycamera` |
| 平台 | iOS（iPhone，iOS 16+） |
| 备案类型 | `- [ ]` 非经营性 · `- [x]` **经营性**（含 IAP / 订阅 / 广告，待法务终认） |
| 服务类目（示例） | 摄影摄像 / 工具 / 社交（家庭圈）— 以备案平台选项为准 |
| 接入商 | `{{ACCESS_PROVIDER}}` |
| 属地管局 | `{{PROVINCIAL_MIIT}}` |
| 备案平台订单号 | `{{FILING_ORDER_ID}}` |

---

## 2. App 名称一致性约束

> **强约束（T0.10 验收）**：以下四处名称必须 **完全一致**，任一变更需重新评估备案。

| 位置 | 当前值 | 一致 |
| --- | --- | :---: |
| 本 Tracker 备案 App 名称 | 宝宝成长相机 | - [x] |
| App Store Connect App 名称 | 宝宝成长相机 | - [ ] 待 T0.12 Apple 账号开通后创建 App 并确认 |
| ICP 备案平台填写 App 名称 | 宝宝成长相机 | - [ ] 待提交 |
| 用户可见启动页 / 关于（可选副标题除外） | 宝宝成长相机 | - [ ] 待 iOS 定稿 |

**名称变更记录**：

| 日期 | 原名称 | 新名称 | 是否重新备案 | 审批人 |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

---

## 3. 主体信息（摘要）

> 明细见 [SUBJECT_VERIFICATION.md](./SUBJECT_VERIFICATION.md) §5。

| 字段 | 值 |
| --- | --- |
| 备案主体 | `{{COMPANY_NAME}}` |
| 统一社会信用代码 | `{{USCC}}` |
| 法定代表人 | `{{LEGAL_REP}}` |
| 备案负责人 | `{{FILING_CONTACT}}` / `{{FILING_PHONE}}` |

---

## 4. 备案号占位

| 字段 | 占位值 | 正式值（T7.2 回填） | 状态 |
| --- | --- | --- | --- |
| **App ICP 备案号** | `京ICP备00000000号-9S`（staging，见 `compliance/client-config.yaml`） | _待管局下发_ | staging 占位 |
| 网站 ICP 备案号（隐私政策域名，如有） | `{{WEB_ICP_NUMBER}}` | _待填_ | 未下发 |
| 查询链接 | [工信部 ICP/IP 地址/域名信息备案管理系统](https://beian.miit.gov.cn/) | — | — |

**远端配置 key**（T6.10 / config-svc）：

```json
{
  "compliance.icp_number": "京ICP备00000000号-9S",
  "compliance.icp_query_url": "https://beian.miit.gov.cn/"
}
```

---

## 5. 流程状态

```text
[ ] 主体确认  →  [ ] 材料齐备  →  [ ] 已提交  →  [ ] 管局受理  →  [ ] 审核中  →  [ ] 已通过  →  [ ] T7.2 已回填
     ↑ SUBJECT_VERIFICATION.md 全部完成
```

| 里程碑 | 目标日期 | 实际日期 | 状态 | 备注 |
| --- | --- | --- | --- | --- |
| M1 主体可用确认 | W0 | | - [ ] | SUBJECT_VERIFICATION 签字 |
| M2 材料提交 | W1 | | - [ ] | |
| M3 **管局受理** | W2 | | - [ ] | 受理回执编号：____________ |
| M4 管局审核通过 | W8–W12（估算） | | - [ ] | 与 P7 T7.2 汇合 |
| M5 备案号回填上线 | W12+ | | - [ ] | config-svc + 关于页 |

**当前阶段**：`M1 主体确认中`

---

## 6. 提交 / 受理回执

| 项 | 内容 |
| --- | --- |
| 提交日期 | |
| 提交渠道 | `- [ ]` 接入商平台 · `- [ ]` Apple 备案通道 · `- [ ]` 其他：____ |
| 受理回执编号 | `{{ACCEPTANCE_RECEIPT_ID}}` |
| 受理日期 | |
| 回执扫描件 | `compliance/icp-filing/receipts/`（待上传，勿提交 Git 若含敏感信息） |
| 预计办结 | |

**材料清单（提交前勾选）**：

- [ ] 营业执照副本
- [ ] 法定代表人身份证（正反面）
- [ ] 备案负责人身份证 + 核验照片
- [ ] App 图标（1024×1024）
- [ ] App 简介 / 功能说明（与 PRD 一致）
- [ ] 隐私政策 URL（可先 staging，T7.2 正式）
- [ ] 服务器接入信息 / 域名证书
- [ ] 真实性承诺书（平台模板）
- [ ] 经营性：电信业务经营许可证（若要求）

---

## 7. 周状态跟踪

| 周次 | 日期 | 状态摘要 | 阻塞项 | 下一步 | 更新人 |
| --- | --- | --- | --- | --- | --- |
| W0 | 2026-06-06 | T0.10 文档就绪；主体待确认 | 主体方案未最终选定 | 完成 SUBJECT_VERIFICATION | COMP |
| W1 | | | | | |
| W2 | | | | | |
| W3 | | | | | |
| W4 | | | | | |

---

## 8. 与下游任务对接

| 下游 | 依赖本 Tracker 字段 | 动作 |
| --- | --- | --- |
| T6.10 iOS 设置关于 | `compliance.icp_number` | 占位已定义，正式号下发后改 config-svc |
| T7.2 ICP + 政策 | 正式 `{{ICP_NUMBER}}` | 隐私政策页脚、用户协议 |
| T7.13 App Store 提审 | App 名称 + ICP 号 | 与 APP_STORE_METADATA 一致 |
| T7.14 渐进发布 | 备案已通过 | 中国区上架前置条件 |

---

## 9. 更新记录

| 日期 | 变更 |
| --- | --- |
| 2026-06-06 | T0.10 初版；备案号占位 `{{ICP_NUMBER}}` |
