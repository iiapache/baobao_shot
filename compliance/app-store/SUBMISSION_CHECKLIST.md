# App Store 提审自查清单（T7.13）

> **任务**：T7.13  
> **App**：宝宝成长相机（`com.babycamera.app`）  
> **关联**：`docs/dev-plan.md` T7.13、`docs/PRD.md` §6.5、`compliance/icp-filing/APP_STORE_METADATA_PLACEHOLDER.md`  
> **最后更新**：2026-06-06

---

## 使用说明

1. 提审前由 **COMP** 牵头，**iOS / BE / QA** 按角色勾选。
2. 每项须附证据（截图、URL、代码路径或测试记录）。
3. 未勾选项须在提审备注中说明计划与风险（见 `APP_REVIEW_NOTES.md`）。
4. 重点对照 Apple [Guideline 4.5.4](https://developer.apple.com/app-store/review/guidelines/#subscriptions)（订阅披露）与 [4.7](https://developer.apple.com/app-store/review/guidelines/#mini-apps)（远端内容/代码）。

---

## A. 元数据与政策（T7.2）

| # | 检查项 | 负责人 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| A1 | App Store 名称「宝宝成长相机」与 ICP 备案系统一致 | COMP | ☐ | `APP_STORE_METADATA_PLACEHOLDER.md` §1 |
| A2 | 描述页脚含隐私政策 / 用户协议 / SDK 清单链接（含版本号） | COMP | ☐ | ASC 描述草稿 |
| A3 | `{{ICP_NUMBER}}` 已在 Tracker、config-svc、关于页、政策页 **一致** | COMP + BE | ☐ | `ICP_FILING_TRACKER.md` |
| A4 | 政策 URL 在 ASC + App 内可打开（CN 区） | QA | ☐ | 真机截图 |
| A5 | 政策版本号与 `compliance/policies/*.md` frontmatter 一致 | COMP | ☐ | v1.0.0 对照 |
| A6 | App 内「设置 → 关于」展示用户协议 / 隐私政策 / 深度合成说明 / SDK 清单 | iOS | ☐ | T6.10 截图 |
| A7 | 运营主体 `{{COMPANY_NAME}}` 与备案主体一致 | COMP | ☐ | `SUBJECT_VERIFICATION.md` |

---

## B. 算法备案号（T7.1）

| # | 检查项 | 负责人 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| B1 | 中国区 4 模型备案号已获批并回填 `filings.yaml` | COMP + BE | ☐ | `MODEL_FILING_TRACKER.md` 回填区 |
| B2 | `ai-dispatch-svc` 缺备案号模型拒绝路由（CN） | BE + QA | ☐ | `AI_MODEL_FILING_REQUIRED` 回归 |
| B3 | App「设置 → 关于 → 算法备案号」展示 `config-svc` 摘要 | iOS + QA | ☐ | `compliance.algorithm_filing_summary` |
| B4 | ASC 描述 / 审核备注已说明备案号见 App 内关于页 | COMP | ☐ | `APP_REVIEW_NOTES.md` |
| B5 | 未备案玩法在 CN 区不可见（`GET /v1/ai/plays` 过滤） | BE + QA | ☐ | CN 区玩法列表截图 |
| B6 | 深度合成说明网页与 App 内入口可访问 | COMP | ☐ | `deep-synthesis-notice.md` |

---

## C. 深度合成合规（T7.2 / PRD §6.2）

| # | 检查项 | 负责人 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| C1 | AI 输出强制「AI 生成 · 深度合成」角标（不可关闭） | iOS + QA | ☐ | 编辑器 / 分享截图 |
| C2 | 分享文案默认含 AI 辅助提示 | iOS | ☐ | 分享面板截图 |
| C3 | 深度合成说明覆盖能力范围、标识、权利义务、投诉 | COMP | ☐ | `deep-synthesis-notice.md` |
| C4 | 监护人同意前 AI 玩法受限（T7.3） | QA | ☐ | `p7-child-consent-e2e.sh` |
| C5 | 入参 / 出参 / UGC 审核全链路 e2e 通过（T7.5） | QA | ☐ | 审核 e2e 报告 |

---

## D. 订阅披露 — Apple 4.5.4（T4.13 / PRD §4.11.4）

| # | 检查项 | 负责人 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| D1 | 订阅页展示**价格**（StoreKit 本地化价或 API `priceCny`） | iOS | ☐ | `SubscriptionView` 截图 |
| D2 | 订阅页展示**续费周期**与**自动续订**说明 | iOS + COMP | ☐ | `SUBSCRIPTION_DISCLOSURE.md` §2 |
| D3 | 订阅页展示**取消方式**（设置 → Apple ID → 订阅） | iOS | ☐ | 披露文案截图 |
| D4 | 明确订阅**不含 AI 算力**（算力走积分） | COMP | ☐ | 订阅页 / 充值页文案 |
| D5 | 宽限期 / 过期 / 退款状态在 App 内可读 | iOS | ☐ | `SubscriptionStore` 状态截图 |
| D6 | ASC「App 内购买项目」订阅组与 `IAP_PRODUCTS.md` 一致 | COMP | ☐ | ASC IAP 配置截图 |
| D7 | 终身会员按**非续期购买**配置（非自动续订订阅组） | COMP | ☐ | ASC 产品类型 |
| D8 | 免费试用（如有）在披露文案中明示试用结束后的扣费 | COMP | ☐ | ASC 试用配置 |

**4.5.4 专项结论**：

- ☐ **通过**：D1–D8 全部满足，披露文案见 `SUBSCRIPTION_DISCLOSURE.md`
- ☐ **有条件通过**：备案号 / ICP 仍为占位，已在审核备注说明
- ☐ **不通过**：____（阻塞项）

---

## E. 内购清单（PRD §4.11.2 / §4.11.4）

| # | 检查项 | 负责人 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| E1 | 4 档积分充值 Product ID 与代码 / 后端 catalog 一致 | BE + iOS | ☐ | `IAP_PRODUCTS.md` |
| E2 | 4 档订阅 Product ID 与 `SubscriptionProductID` 一致 | iOS | ☐ | `SubscriptionModels.swift` |
| E3 | ASC 已创建全部 IAP 并关联订阅组 | COMP | ☐ | ASC 后台 |
| E4 | Sandbox 真机购买闭环（积分 + 订阅） | QA | ☐ | `p4-e2e.sh` / TestFlight |
| E5 | 积分消耗不退、未消耗 7 日内可退款提示可见 | iOS | ☐ | 充值页文案 |
| E6 | Apple Server Notifications v2 已配置（退款 / 撤销） | BE | ☐ | `iap-callback-svc` |

---

## F. App Privacy 隐私问卷（ASC）

| # | 数据类型 | 是否收集 | 用途 | 是否关联用户 | 是否用于跟踪 | 依据 |
| --- | --- | --- | --- | --- | --- | --- |
| F1 | 联系信息（手机号） | 是 | 账号登录 | 是 | 否 | 隐私政策 §一 |
| F2 | 标识符（Apple Sub、设备 ID） | 是 | 登录 / 推送 / 分析 | 是 | 否 | TokenStore / APNs |
| F3 | 照片 / 视频 | 是 | 核心功能 / AI | 是 | 否 | 相机 / 编辑器 |
| F4 | 用户内容（Feed 文字） | 是 | 家庭圈 UGC | 是 | 否 | feed-svc |
| F5 | 购买记录 | 是 | IAP / 订阅 | 是 | 否 | credit-sub-ad-svc |
| F6 | 诊断（崩溃日志） | 是 | 稳定性 | 可脱敏 | 否 | Bugly / Sentry |
| F7 | 位置（粗略） | 可选 | 时间线地图 | 是 | 否 | 用户授权后 |
| F8 | 广告数据 | 是（非订阅用户） | 广告展示 | 部分 | **否**¹ | 穿山甲 / 优量汇 |

> ¹ 本 App **不申请 ATT**（见 §G）；问卷中「用于跟踪」选 **否**，并在审核备注说明理由。

| # | 检查项 | 负责人 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| F9 | 问卷答案与 `privacy-policy-cn.md` + `third-party-sdk-list.md` 一致 | COMP | ☐ | ASC Privacy 导出 |
| F10 | 第三方 SDK 隐私链接已在问卷中标注 | COMP | ☐ | SDK 清单 |
| F11 | 隐私营养标签已上传隐私政策 URL | COMP | ☐ | ASC 配置 |
| F12 | 儿童类别：已说明 14 岁以下须监护人同意 | COMP | ☐ | T7.3 同意书 |

---

## G. ATT 不申请说明

| # | 检查项 | 负责人 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| G1 | `Info.plist` **无** `NSUserTrackingUsageDescription` | iOS | ☐ | plist 审查 |
| G2 | 工程**未链接** `AppTrackingTransparency.framework` | iOS | ☐ | Xcode 依赖检查 |
| G3 | 代码**无** `ATTrackingManager.requestTrackingAuthorization` 调用 | iOS | ☐ | 全仓 grep |
| G4 | 第一方分析（ClickHouse 埋点）不使用 IDFA 跨 App 跟踪 | BE + iOS | ☐ | `AnalyticsService` |
| G5 | 广告 SDK 按区域延迟初始化；订阅用户不展示广告 | iOS | ☐ | 广告模块 |
| G6 | ASC 隐私问卷「跟踪」= 否；审核备注已附 ATT 说明 | COMP | ☐ | `APP_REVIEW_NOTES.md` §ATT |

**不申请 ATT 理由（摘要）**：

- 产品不使用 IDFA 进行跨 App / 跨站用户跟踪；
- 分析为第一方产品改进，数据不与第三方数据经纪商关联；
- 中国区广告联盟 SDK 在儿童相关场景延迟加载，且不将数据用于 Apple 定义的「跟踪」；
- 用户可在 iOS 系统设置中限制广告跟踪（我们引导见隐私政策）。

---

## H. 远端配置 — Apple 4.7（config-svc / PRD §6.5）

| # | 检查项 | 负责人 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| H1 | 远端下发内容为 **JSON 配置**（玩法目录 / 模板 manifest / Feature Flag） | BE + iOS | ☐ | `config-svc` + design-ios §8.2 |
| H2 | **不下发**可执行代码（JS/WASM/动态库/脚本解释器） | BE + iOS | ☐ | 架构审查 |
| H3 | 模板资源（贴纸 / 字体 / 背景）**打包在 App 内** | iOS | ☐ | design-ios §8.2 |
| H4 | AI 玩法仅切换已审核二进制内的 UI 与 API 路由参数 | BE | ☐ | `GET /v1/ai/plays` schema |
| H5 | 远端配置变更不引入新二进制能力（仅显隐 / 排序 / 文案 / 定价展示） | PM + BE | ☐ | config-svc 变更 SOP |
| H6 | 审核备注已说明远端配置机制与 4.7 合规边界 | COMP | ☐ | `APP_REVIEW_NOTES.md` §远端配置 |
| H7 | 提审版本 config snapshot 版本号已记录 | BE | ☐ | `config-svc` Version 字段 |

**4.7 专项结论**：

- ☐ **通过**：H1–H7 满足；远端仅为数据配置，无代码热更新
- ☐ **不通过**：____（阻塞项）

---

## I. 账号、演示与审核辅助

| # | 检查项 | 负责人 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| I1 | 提供审核用沙盒 Apple ID + 演示手机号 | QA | ☐ | `APP_REVIEW_NOTES.md` §演示账号 |
| I2 | 审核备注含核心路径操作说明（拍照 → AI → 订阅 → 分享） | QA | ☐ | 审核备注 |
| I3 | 微信分享：仅朋友圈/好友，失败可走系统分享 | iOS | ☐ | T5.14 |
| I4 | 账号注销与数据导出入口可用（PRD §6.4） | iOS + QA | ☐ | 设置 → 数据 |
| I5 | 出口合规 / 加密声明（ATS + 标准 HTTPS） | iOS | ☐ | ASC 出口合规 |

---

## J. 提审前最终签字

| 角色 | 姓名 | 日期 | 签字 |
| --- | --- | --- | --- |
| COMP | | | ☐ |
| iOS Lead | | | ☐ |
| BE Lead | | | ☐ |
| QA Lead | | | ☐ |

---

## 关联文档

| 文档 | 用途 |
| --- | --- |
| [APP_REVIEW_NOTES.md](./APP_REVIEW_NOTES.md) | App Store Connect 审核备注正文 |
| [IAP_PRODUCTS.md](./IAP_PRODUCTS.md) | IAP / 订阅 Product ID 与价格占位 |
| [SUBSCRIPTION_DISCLOSURE.md](./SUBSCRIPTION_DISCLOSURE.md) | 4.5.4 订阅披露文案 |
| [APP_STORE_METADATA_PLACEHOLDER.md](../icp-filing/APP_STORE_METADATA_PLACEHOLDER.md) | 元数据与 config-svc 交叉引用 |
| [deep-synthesis-notice.md](../policies/deep-synthesis-notice.md) | 深度合成说明 |
| [filings.yaml](../algorithm-filing/filings.yaml) | 算法备案号绑定 |

---

## 更新记录

| 日期 | 变更 |
| --- | --- |
| 2026-06-06 | T7.13 初版：提审自查清单（含 4.5.4 / 4.7 / ATT / 隐私问卷） |
