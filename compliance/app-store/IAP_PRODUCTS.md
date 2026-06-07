# 内购清单与价格占位（T7.13）

> **任务**：T7.13  
> **Bundle ID**：`com.babycamera.app`  
> **数据源**：PRD §4.11.2 / §4.11.4、`IAPModels.swift`、`SubscriptionModels.swift`、`credit-sub-ad-svc` catalog  
> **关联**：[SUBSCRIPTION_DISCLOSURE.md](./SUBSCRIPTION_DISCLOSURE.md)、[SUBMISSION_CHECKLIST.md](./SUBMISSION_CHECKLIST.md)  
> **最后更新**：2026-06-06

---

## 1. 总览

| 类型 | 数量 | StoreKit 类型 | 订阅组 |
| --- | --- | --- | --- |
| 积分充值（消耗型） | 4 | Consumable | — |
| 自动续订订阅 | 3 | Auto-Renewable Subscription | `babycamera_premium` |
| 终身会员（非续期） | 1 | Non-Consumable 或 Non-Renewing Subscription¹ | — |

> ¹ **建议**：终身会员在 ASC 配置为 **Non-Consumable**（一次性购买），避免与自动续订组混淆。若使用 Non-Renewing Subscription，须在披露文案中说明有效期。

---

## 2. 积分充值（Consumable）

> PRD §4.11.2；后端主键见 `iap.DefaultProductCatalog`；iOS 主键见 `CreditIAPProductID`。

| 档位 | Product ID（主） | Product ID（兼容别名） | 积分 | 建议零售价（CNY） | ASC 价格档位占位 | 状态 |
| --- | --- | --- | ---: | ---: | --- | --- |
| 体验装 | `credit_pack_60` | `com.baobao.credits.60` | 60 | ¥6 | Tier 6（¥6） | ⬜ ASC 待创建 |
| 入门装 | `credit_pack_330` | `com.baobao.credits.330` | 330 | ¥30 | Tier 30（¥30） | ⬜ ASC 待创建 |
| 常用装 | `credit_pack_800` | `com.baobao.credits.800` | 800 | ¥68 | Tier 68（¥68） | ⬜ ASC 待创建 |
| 大礼包 | `credit_pack_2500` | `com.baobao.credits.2500` | 2500 | ¥198 | Tier 198（¥198） | ⬜ ASC 待创建 |

### 2.1 展示名称（ASC 参考）

| Product ID | 显示名称（中文） | 描述摘要 |
| --- | --- | --- |
| `credit_pack_60` | 体验装 · 60 积分 | 用于 AI 玩法算力消耗；积分一经使用不可退还 |
| `credit_pack_330` | 入门装 · 330 积分 | 同上 |
| `credit_pack_800` | 常用装 · 800 积分 | 同上 |
| `credit_pack_2500` | 大礼包 · 2500 积分 | 同上 |

### 2.2 退款与消耗规则（须在充值页展示）

- 积分**一经消耗不可退还**（界面强提示）；
- 未消耗部分支持 **7 日内**按 Apple 退款流程申请整笔退款；
- 校验接口：`POST /v1/credits/iap-verify`（StoreKit 2 JWS）。

---

## 3. 自动续订订阅（Auto-Renewable）

> PRD §4.11.4；后端见 `subscription.DefaultProductCatalog`；iOS 见 `SubscriptionProductID`。  
> **订阅组 ID 建议**：`babycamera_premium`

| 方案 | Product ID | 周期 | 建议零售价（CNY） | 折合单价 | 赠送积分 | ASC 状态 |
| --- | --- | --- | ---: | --- | ---: | --- |
| 月会员 | `com.baobao.sub.monthly` | 1 个月 | ¥18 | ¥18/月 | — | ⬜ 待创建 |
| 季会员 | `com.baobao.sub.quarterly` | 3 个月 | ¥45 | ¥15/月 | — | ⬜ 待创建 |
| 年会员 | `com.baobao.sub.yearly` | 1 年 | ¥128 | ≈¥10.7/月 | 200 | ⬜ 待创建 |

### 3.1 订阅权益（不含 AI 算力）

| 权益 | 说明 |
| --- | --- |
| 去广告 | 开屏 / 插页广告不再展示 |
| 品牌水印可关 | 「AI 生成 · 深度合成」角标仍保留 |
| 滤镜全开 | 全部滤镜无限制 |
| 年度回顾 | 免费重生成 1 次/年 |

> **重要**：订阅不包含 AI 算力；AI 玩法始终消耗积分（PRD §4.11.4）。

### 3.2 兼容别名（仅测试 / 旧 mock）

| Product ID | 说明 |
| --- | --- |
| `sub_monthly` | e2e / 埋点示例用；**生产 ASC 不创建** |

---

## 4. 终身会员（一次性购买）

| 方案 | Product ID | 建议零售价（CNY） | 赠送积分 | ASC 类型建议 | 状态 |
| --- | --- | ---: | ---: | --- | --- |
| 终身会员 | `com.baobao.sub.lifetime` | ¥498 | 500 | Non-Consumable | ⬜ 待创建 |

- 权益同 §3.1，永久有效；
- **非自动续订**，无需在订阅管理页展示续费周期；
- 限量首发策略由运营在 ASC 促销配置，不影响 Product ID。

---

## 5. App Store Connect 配置检查表

| # | 配置项 | 说明 | 状态 |
| --- | --- | --- | --- |
| 1 | 协议 / 税务 / 银行 | 付费 App 协议有效 | ☐ |
| 2 | 订阅组 `babycamera_premium` | 月 / 季 / 年同级，可互相升级 | ☐ |
| 3 | 订阅本地化 | 中文名称 + 权益描述 | ☐ |
| 4 | 订阅审核截图 | 订阅页含价格 / 续费 / 取消说明 | ☐ |
| 5 | Server Notifications V2 | 指向 `iap-callback-svc` | ☐ |
| 6 | Sandbox 测试员 | 至少 2 个沙盒账号 | ☐ |
| 7 | 价格占位最终确认 | PRD §12.1 待拍板项 #1 | ☐ |

---

## 6. 与后端 / 端侧对齐验证

```bash
# 积分 catalog（Go）
grep -A20 'DefaultProductCatalog' services/credit-sub-ad-svc/internal/iap/catalog.go

# 订阅 catalog（Go）
grep -A10 'DefaultProductCatalog' services/credit-sub-ad-svc/internal/subscription/catalog.go

# iOS Product ID
grep -E 'pack|sub\.' ios/Packages/BabyCameraCredit/Sources/BabyCameraCredit/Models/*.swift
```

| 对齐项 | 后端 | iOS | 一致 |
| --- | --- | --- | --- |
| 积分主 ID | `credit_pack_*` | `CreditIAPProductID` | ✓ |
| 订阅 ID | `com.baobao.sub.*` | `SubscriptionProductID` | ✓ |
| 积分数量 | catalog map | `creditsByProductID` | ✓ |

---

## 7. 海外区（OS）价格占位

> V1 首上架以 CN 为主；OS 区价格由 ASC 按地区自动换算，建议与 CNY 草案保持近似购买力。

| Product ID | 建议 USD 占位 | 备注 |
| --- | ---: | --- |
| `credit_pack_60` | $0.99 | 待 REGION=OS 上架时创建 |
| `com.baobao.sub.monthly` | $2.99 | StoreKit 2 已支持 OS（`iap.os_storekit2` flag） |

---

## 8. 更新记录

| 日期 | 变更 |
| --- | --- |
| 2026-06-06 | T7.13 初版：IAP 清单与 PRD 价格占位 |
