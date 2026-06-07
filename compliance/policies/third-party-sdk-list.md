---
title: 第三方 SDK 清单
version: v1.0.0
effective_date: 2026-06-06
locale: zh-CN
document_id: third-party-sdk-list
---

# 第三方 SDK 清单

**版本**：v1.0.0  
**生效日期**：2026 年 6 月 6 日

## 摘要

下列 SDK 可能随 App 版本与区域（CN / OS）不同而有所差异。我们仅接入提供服务所必需的 SDK，并在隐私政策中说明数据用途。儿童相关页面加载前，广告类 SDK 按设计规范延迟初始化。

## 清单（占位）

| SDK 名称 | 提供方 | 主要功能 | 可能收集的信息 | 适用区域 | 隐私政策链接 |
| --- | --- | --- | --- | --- | --- |
| 微信 OpenSDK | 腾讯 | 分享至朋友圈/好友 | 设备信息、分享元数据 | CN | 腾讯隐私政策（占位 URL） |
| 穿山甲 / 优量汇 | 字节 / 腾讯 | 广告展示 | 广告标识符、设备信息 | CN | 各平台隐私说明（占位） |
| AdMob | Google | 广告展示 | 广告标识符 | OS | https://policies.google.com/privacy |
| APNs | Apple | 推送通知 | 设备 Token | CN / OS | Apple 隐私政策 |
| Bugly | 腾讯 | 崩溃统计 | 崩溃堆栈、设备型号（脱敏） | CN | 占位 |
| Sentry | Functional Software | 错误监控 | 崩溃事件、版本号 | CN / OS | https://sentry.io/privacy/ |
| 百度网盘 OpenAPI | 百度 | 云备份 | 授权 Token、文件元数据 | CN | 百度隐私政策（占位） |
| StoreKit 2 | Apple | 内购订阅 | 交易凭证 | CN / OS | Apple 隐私政策 |

## 退出与限制

- **广告**：订阅用户自动去广告；可在系统设置中限制广告跟踪（OS ATT 说明见 T7.13）；
- **推送**：可在 App「设置 → 通知」关闭；
- **备份**：可在「设置 → 数据」解除第三方云盘授权；
- **分享**：微信分享失败时可使用系统分享兜底。

## 更新

SDK 版本升级或增删时，我们将更新本清单版本号并同步 config-svc `compliance.policy_versions.third_party_sdk`。当前版本：**v1.0.0**。

---

*本文档为 T7.2 结构占位；正式提审前须核对各 SDK 厂商最新隐私条款。*
