# On-Demand Resources（ODR）配置说明

> 任务 **T7.7** · 对齐 [design-ios.md §14 性能预算](../../docs/design-ios.md#14-性能预算与冷启动)  
> 目标：安装包 ≤ **80 MB**（App Store 下载体积），贴纸 / 字体等大资源走 ODR 按需下载。

## 1. 资源 Tag 规划

| Tag | 内容 | 预估体积 | 加载时机 |
| --- | --- | --- | --- |
| `editor-fonts` | 编辑器 TTF 字体包 | ~15 MB | 用户首次进入 TextStep |
| `editor-stickers` | 贴纸 PNG / WebP 合集 | ~25 MB | 用户首次进入 StickerStep |
| `ai-style-presets` | AI 玩法预览图（可选） | ~10 MB | 玩法详情页 |

主包仅保留启动必需资源（图标、核心 UI、相机默认滤镜 LUT 等）。

## 2. Asset Catalog 占位

`BabyCamera/Resources/ODRAssets.xcassets/` 内含带 ODR tag 的占位 imageset，用于验证 Xcode 配置与 Archive 分包。

每个 imageset 的 `Contents.json` 示例：

```json
{
  "properties": {
    "on-demand-resource-tags": ["editor-stickers"]
  }
}
```

## 3. Xcode 配置步骤

1. **Target → Build Phases → On Demand Resources**  
   - 添加 Tags：`editor-fonts`、`editor-stickers`
2. **Asset Catalog**  
   - 选中大体积 imageset / dataset → Attributes Inspector → On Demand Resource Tags
3. **代码加载**（编辑器模块）

```swift
let request = NSBundleResourceRequest(tags: ["editor-fonts"])
request.beginAccessingResources { error in
    guard error == nil else { return }
    // 注册字体 / 加载贴纸
}
```

`BabyCameraEditor` 中 `FontCatalog` / `StickerCatalog` 已预留 Bundle / ODR 注入点。

## 4. 体积验收

```bash
# 估算 IPA / 安装包（不含 ODR 按需包）
./scripts/measure-ipa-size.sh path/to/BabyCamera.ipa

# 或 Archive 产物
./scripts/measure-ipa-size.sh ~/Library/Developer/Xcode/Archives/.../BabyCamera.xcarchive
```

| 指标 | 预算 | 说明 |
| --- | --- | --- |
| 主包 IPA（压缩后） | ≤ 80 MB | `measure-ipa-size.sh` 输出 `INSTALL_SIZE` |
| ODR 资源 | 不计入主包预算 | App Store Connect → App Size 可查看按需资源 |
| Widget Extension | ≤ 5 MB | 独立 target，见 T6.9 |

## 5. App Store Connect 说明文案（提审用）

> 贴纸与装饰字体通过 iOS On-Demand Resources 在用户首次使用相关编辑功能时按需下载，不计入初始安装包体积。用户可在「设置 → 数据 → 清理缓存」释放已下载 ODR 缓存。

## 6. 相关文档

- [design-assets/README.md](../../design-assets/README.md) — 字体 / 贴纸 manifest
- [infra/observability/sentry/ios-integration.md](../../infra/observability/sentry/ios-integration.md) — 崩溃双采集
- [docs/qa/CRASH_MEMORY_SIZE_REPORT_TEMPLATE.md](../../docs/qa/CRASH_MEMORY_SIZE_REPORT_TEMPLATE.md) — QA 报告模板
