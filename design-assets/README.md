# 设计资源包（design-assets）

> **任务**: T0.11（COMP）· 字体商用授权 + 贴纸 + 模板版权采购与设计资源包  
> **对齐**: T2.13 StickerStep / TextStep · T2.14 TemplateStep · design-ios §8.2

## 目录结构

```
design-assets/
├── README.md                    # 本文件
├── PROCUREMENT_TRACKER.md       # 采购与授权跟踪表
├── LICENSES/                    # 法务授权 PDF 存档
│   ├── fonts/                   # 6 款字体授权
│   └── assets/                  # 贴纸/模板主授权
├── fonts/
│   ├── manifest.json            # TextStep 字体清单（ODR: editor-fonts）
│   ├── LICENSE/
│   └── <font-family>/           # 6 款字体目录
├── stickers/
│   ├── manifest.json            # StickerStep 贴纸清单（ODR: editor-stickers）
│   └── <category>/              # 8 类分类目录
└── templates/
    ├── manifest.json            # TemplateStep 总 manifest（config-svc 远端下发）
    ├── growth-card/             # 成长卡片 × 4
    ├── hundred-day/             # 百天卡 × 4
    └── first-birthday/          # 周岁卡 × 4
```

## 数量覆盖

| 资源 | 验收目标 | manifest 数量 |
| --- | --- | --- |
| 字体 | ≥ 6 款商用授权 | 6 |
| 贴纸 | ≥ 60 个 | 72 |
| 模板 | ≥ 12 套 | 12 |

## iOS 编辑器集成（T2.13 / T2.14）

### TextStep（T2.13）

- 读取 `fonts/manifest.json`，按 `postScriptName` 注册到 `Resources/Fonts/`
- ODR tag: `editor-fonts`（design-ios §14 安装包 ≤ 80MB）
- 字体授权与 `LICENSES/fonts/` PDF 一一对应

### StickerStep（T2.13）

- 读取 `stickers/manifest.json`，按 `category` 分组展示
- 分类：数字 / 节日 / 文字 / 动物 / 食物 / 日常 / 里程碑 / 可爱表情（PRD §4.4）
- ODR tag: `editor-stickers`
- `StickerStep` 引用 `id` + `defaultScale`

### TemplateStep（T2.14）

- 启动时预拉 `templates/manifest.json`（design-ios §14 编辑器打开 ≤ 500ms）
- 远端 config-svc 下发增量 manifest，**不下发可执行代码**（design-ios §8.2）
- 模板 = `[EditStep]` + placeholders（人脸/文案/日期）
- 资源（背景/字体/贴纸）打包在 App，manifest 仅 JSON

## 交付与验收

1. **法务**: 授权 PDF 入 `LICENSES/`，更新 `PROCUREMENT_TRACKER.md`
2. **设计**: 替换各目录 `.placeholder` 为正式 PNG/TTF/JPG
3. **iOS**: manifest JSON 对接 Editor Feature，ODR 分包验证
4. **QA**: 核对 manifest 数量 ≥ 验收阈值

## 相关文档

- [dev-plan T0.11](../docs/dev-plan.md) — 版权采购任务
- [design-ios §8](../docs/design-ios.md) — 编辑器架构
- [PRD §4.4](../docs/PRD.md) — 本地编辑功能范围
