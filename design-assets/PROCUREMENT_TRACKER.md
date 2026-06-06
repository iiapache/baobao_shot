# 设计资源采购跟踪表

> T0.11 产出 · 与 T2.13/T2.14 编辑器需求对齐

## 状态说明

| 状态 | 含义 |
| --- | --- |
| 待采购 | 尚未签约或付款 |
| 待设计 | 已签约，设计稿进行中 |
| 待验收 | 资源已交付，待 QA/法务验收 |
| 已存档 | 授权 PDF 已入 LICENSES/，manifest 已更新 |

## 资源跟踪

| ID | 类型 | 名称 | 供应商 | 授权类型 | 状态 | 有效期 | 授权文件 | 编辑器对齐 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| font_baobao_rounded | 字体 | 宝宝圆体 | 汉仪字库 | 商用授权 | 待采购 | — | `LICENSES/fonts/font_baobao_rounded.pdf` | T2.13 TextStep |
| font_baobao_serif | 字体 | 宝宝宋体 | 方正字库 | 商用授权 | 待采购 | — | `LICENSES/fonts/font_baobao_serif.pdf` | T2.13 TextStep |
| font_baobao_handwriting | 字体 | 宝宝手写体 | 造字工房 | 商用授权 | 待采购 | — | `LICENSES/fonts/font_baobao_handwriting.pdf` | T2.13 TextStep |
| font_baobao_cute | 字体 | 宝宝可爱体 | 字魂网 | 商用授权 | 待采购 | — | `LICENSES/fonts/font_baobao_cute.pdf` | T2.13 TextStep |
| font_baobao_bold | 字体 | 宝宝粗黑体 | 思源黑体（Adobe/Google 开源 + 商用扩展） | SIL OFL 1.1 + 商用扩展 | 待采购 | — | `LICENSES/fonts/font_baobao_bold.pdf` | T2.13 TextStep |
| font_baobao_elegant | 字体 | 宝宝雅宋 | 华康字体 | 商用授权 | 待采购 | — | `LICENSES/fonts/font_baobao_elegant.pdf` | T2.13 TextStep |
| stickers_pack | 贴纸 | 宝宝主题贴纸库（70 个） | 自研/采购 | 商用授权 | 待采购 | — | `LICENSES/assets/stickers_master_license.pdf` | T2.13 StickerStep |
| tpl_growth_01 | 模板 | 成长卡片 · 简约白 | 自研/采购 | 商用授权 | 待设计 | — | `LICENSES/assets/templates_master_license.pdf` | T2.14 TemplateStep |
| tpl_growth_02 | 模板 | 成长卡片 · 暖色渐变 | 自研/采购 | 商用授权 | 待设计 | — | `LICENSES/assets/templates_master_license.pdf` | T2.14 TemplateStep |
| tpl_growth_03 | 模板 | 成长卡片 · 胶片边框 | 自研/采购 | 商用授权 | 待设计 | — | `LICENSES/assets/templates_master_license.pdf` | T2.14 TemplateStep |
| tpl_growth_04 | 模板 | 成长卡片 · 手账风 | 自研/采购 | 商用授权 | 待设计 | — | `LICENSES/assets/templates_master_license.pdf` | T2.14 TemplateStep |
| tpl_hundred_01 | 模板 | 百天卡 · 经典红 | 自研/采购 | 商用授权 | 待设计 | — | `LICENSES/assets/templates_master_license.pdf` | T2.14 TemplateStep |
| tpl_hundred_02 | 模板 | 百天卡 · 粉色梦幻 | 自研/采购 | 商用授权 | 待设计 | — | `LICENSES/assets/templates_master_license.pdf` | T2.14 TemplateStep |
| tpl_hundred_03 | 模板 | 百天卡 · 中国风 | 自研/采购 | 商用授权 | 待设计 | — | `LICENSES/assets/templates_master_license.pdf` | T2.14 TemplateStep |
| tpl_hundred_04 | 模板 | 百天卡 · 简约现代 | 自研/采购 | 商用授权 | 待设计 | — | `LICENSES/assets/templates_master_license.pdf` | T2.14 TemplateStep |
| tpl_birthday_01 | 模板 | 周岁卡 · 抓周 | 自研/采购 | 商用授权 | 待设计 | — | `LICENSES/assets/templates_master_license.pdf` | T2.14 TemplateStep |
| tpl_birthday_02 | 模板 | 周岁卡 · 派对 | 自研/采购 | 商用授权 | 待设计 | — | `LICENSES/assets/templates_master_license.pdf` | T2.14 TemplateStep |
| tpl_birthday_03 | 模板 | 周岁卡 · 时光轴 | 自研/采购 | 商用授权 | 待设计 | — | `LICENSES/assets/templates_master_license.pdf` | T2.14 TemplateStep |
| tpl_birthday_04 | 模板 | 周岁卡 · 全家福 | 自研/采购 | 商用授权 | 待设计 | — | `LICENSES/assets/templates_master_license.pdf` | T2.14 TemplateStep |

## 数量覆盖

| 资源类型 | 目标 | 当前 manifest 数量 | 状态 |
| --- | --- | --- | --- |
| 字体 | ≥ 6 | 6 | ✅ manifest 就绪 |
| 贴纸 | ≥ 60 | 72 | ✅ manifest 就绪 |
| 模板 | ≥ 12 | 12 | ✅ manifest 就绪 |

## 变更记录

| 日期 | 变更 | 操作人 |
| --- | --- | --- |
| 2026-06-06 | 初始化 T0.11 资源包结构与 manifest | COMP |
