# 数据导出 Zip 格式说明（T7.18 / T6.11）

> 对齐 iOS `BabyCameraSettings` 模块 `DataExportService` 产出。用户路径：**设置 → 数据 → 导出数据**。

## 概述

| 项 | 说明 |
| --- | --- |
| 文件命名 | `baobao-export-{ISO8601}.zip`（冒号替换为 `-`） |
| 压缩格式 | ZIP（`ZipArchiveWriter`） |
| 内容 | 原图 + 元数据 JSON + 时间线 HTML 预览 |
| 规模目标 | 1 万张照片可成功导出（T6.11 验收） |
| 分享 | 完成后系统分享面板（`UIActivityViewController`） |

## 目录结构

```text
baobao-export-2026-06-06T14-30-00Z.zip
├── metadata.json       # 导出清单（manifest）
├── timeline.html       # 按日分组的时间线预览（相对路径引用 photos/）
└── photos/             # 原图目录
    ├── {photoId}.jpg
    ├── {photoId}.heic
    └── ...
```

常量定义（`DataExportConfiguration`）：

| 常量 | 值 |
| --- | --- |
| `manifestFileName` | `metadata.json` |
| `timelineFileName` | `timeline.html` |
| `photosDirectoryName` | `photos` |

## metadata.json

根对象 `DataExportManifest`，`version` 当前为 **1**。

### 顶层字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `version` | `int` | 格式版本，当前 `1` |
| `exportedAt` | `string` | ISO8601 导出时间 |
| `appVersion` | `string` | App 营销版本号 |
| `familyId` | `string` | 家庭 ID |
| `babies` | `[DataExportBaby]` | 家庭下宝宝档案 |
| `milestones` | `[DataExportMilestone]` | 里程碑记录 |
| `photos` | `[DataExportPhoto]` | 照片元数据（与 zip 内文件一一对应） |

### DataExportBaby

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | `string` | ✓ | 宝宝 ID |
| `name` | `string` | ✓ | 昵称 |
| `gender` | `string` | | 性别 |
| `birthDate` | `string` | ✓ | 出生日期（`YYYY-MM-DD`） |
| `birthTime` | `string` | | 出生时间 |

### DataExportMilestone

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | `string` | ✓ | 里程碑 ID |
| `babyId` | `string` | ✓ | 关联宝宝 |
| `name` | `string` | ✓ | 名称 |
| `date` | `int64` | ✓ | Unix 时间戳（秒） |
| `kind` | `string` | ✓ | 类型（如 `custom`） |

### DataExportPhoto

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | `string` | ✓ | 照片 ID |
| `babyIds` | `[string]` | ✓ | 关联宝宝（可多宝宝） |
| `userId` | `string` | ✓ | 拍摄用户 |
| `takenAt` | `int64` | ✓ | 拍摄时间 Unix 秒 |
| `latitude` | `double` | | 纬度（库内或 EXIF 回填） |
| `longitude` | `double` | | 经度 |
| `sha256` | `string` | ✓ | 文件 SHA256 |
| `exifJSON` | `string` | | EXIF JSON 字符串 |
| `archivePath` | `string` | ✓ | zip 内相对路径，如 `photo_1.heic`（不含 `photos/` 前缀） |
| `localOnly` | `bool` | ✓ | 是否仅本地、未同步云端 |

### 照片文件命名规则

`archivePath` = `{photoId}.{ext}`，扩展名取自本地 `filePath`，**小写**；无扩展名时仅为 `{photoId}`。

示例：`/store/photo_1.JPG` → zip 内 `photos/photo_1.jpg`，manifest 中 `archivePath: "photo_1.jpg"`。

## timeline.html

- 由 `TimelineHTMLGenerator` 根据 manifest 生成，UTF-8 单文件 HTML。
- 图片引用相对路径：`photos/{archivePath}`。
- 按 `takenAt` 日期分组展示；可在浏览器直接打开预览（无需服务端）。

## 导出流程与进度

`DataExportPhase` 阶段（UI 进度条）：

| 阶段 | 说明 |
| --- | --- |
| `preparing` | 统计照片总数、创建 zip |
| `copyingPhotos` | 分页（默认 200 张/页）复制原图入 zip |
| `writingMetadata` | 写入 `metadata.json` |
| `finalizing` | 写入 `timeline.html` 并关闭 zip |
| `completed` | 完成，返回 zip URL |
| `failed` | 失败 |

后台任务标识：`com.babycamera.background.data-export`（`BGTask` / `DataExportBackgroundCoordinator`）。

## 错误码（端侧）

| `DataExportError` | 用户可见含义 |
| --- | --- |
| `familyNotFound` | 无宝宝档案 |
| `noPhotosToExport` | 没有可导出的照片 |
| `missingPhotoFile(photoId:)` | 本地原图缺失 |
| `zipCreationFailed` | 压缩失败 |
| `encodingFailed` | JSON/HTML 编码失败 |
| `cancelled` | 用户取消 |

## 解析示例

### 校验 zip 完整性（macOS）

```bash
unzip -l baobao-export-*.zip | head
unzip -p baobao-export-*.zip metadata.json | jq '.version, .photos | length'
open timeline.html   # 先解压到目录
```

### 最小 manifest 样例

```json
{
  "version": 1,
  "exportedAt": "2026-06-06T14:30:00Z",
  "appVersion": "1.0.0",
  "familyId": "fam_abc",
  "babies": [
    {
      "id": "baby_1",
      "name": "小宝",
      "birthDate": "2024-01-01"
    }
  ],
  "milestones": [],
  "photos": [
    {
      "id": "photo_1",
      "babyIds": ["baby_1"],
      "userId": "user_1",
      "takenAt": 1700000000,
      "sha256": "abc123…",
      "archivePath": "photo_1.heic",
      "localOnly": false
    }
  ]
}
```

## 版本演进

| version | 变更 |
| --- | --- |
| `1` | 初版：原图 + metadata.json + timeline.html（T6.11） |

后续若增加字段，仅追加可选 JSON 字段并递增 `version`；旧版解析器应忽略未知字段。

## 代码参考

| 模块 | 路径 |
| --- | --- |
| 导出服务 | `ios/Packages/BabyCameraSettings/Sources/.../DataExportService.swift` |
| 元数据构建 | `.../DataExportMetadataBuilder.swift` |
| HTML 生成 | `.../TimelineHTMLGenerator.swift` |
| 模型定义 | `.../Models/DataExportModels.swift` |
| 单测 | `ios/Packages/BabyCameraSettings/Tests/.../DataExport*Tests.swift` |

---

*文档版本：T7.18 · 与端侧 `DataExportManifest.currentVersion = 1` 同步*
