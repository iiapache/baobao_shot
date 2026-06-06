# 授权证书存档（法务占位）

> T0.11 验收项：法务存档授权 PDF。

## 目录结构

```
LICENSES/
├── README.md                 # 本说明
├── fonts/                    # 字体商用授权 PDF
│   ├── font_baobao_rounded.pdf
│   ├── font_baobao_serif.pdf
│   ├── font_baobao_handwriting.pdf
│   ├── font_baobao_cute.pdf
│   ├── font_baobao_bold.pdf
│   └── font_baobao_elegant.pdf
└── assets/                   # 贴纸/模板素材授权
    ├── stickers_master_license.pdf
    └── templates_master_license.pdf
```

## 占位 PDF 说明

采购完成前，各 `.pdf.placeholder` 文件标记待交付位置。
法务收到正式授权后：

1. 将 PDF 放入对应路径（替换 `.placeholder`）
2. 更新 `PROCUREMENT_TRACKER.md` 状态为「已存档」
3. 在 Git LFS 或设计仓库独立存储大文件（本仓库仅跟踪 manifest）

## 验收清单

- [ ] 6 款字体授权 PDF 齐全
- [ ] 贴纸库主授权 PDF 齐全
- [ ] 模板素材主授权 PDF 齐全
- [ ] 授权范围覆盖 iOS App 内嵌与 ODR 分发
- [ ] 授权有效期记录于 PROCUREMENT_TRACKER.md
