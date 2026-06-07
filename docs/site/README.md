# BabyCamera 内部文档站（T7.18）

静态文档站，无构建依赖即可浏览首页；API 参考页由 OpenAPI 契约生成。

## 目录

```text
docs/site/
├── index.html          # 文档首页（入口）
├── README.md           # 本文件
└── api/                # 脚本生成（默认 gitignore）
    ├── index.html      # Redoc 单页
    └── swagger/        # 可选 Swagger UI（--swagger）
```

## 生成 API 文档

```bash
chmod +x scripts/generate-api-docs.sh
./scripts/generate-api-docs.sh
```

可选同时生成 Swagger UI 静态页：

```bash
./scripts/generate-api-docs.sh --swagger
```

仅校验 bundle（CI 快速检查）：

```bash
./scripts/generate-api-docs.sh --check
```

依赖：Node.js（`npx` 拉取 `@redocly/cli`）；`--swagger` 额外需要 `curl`。

## 本地预览

### 方式一：Python 静态服务（推荐）

在项目根目录执行：

```bash
# 先生成 API 页
./scripts/generate-api-docs.sh

# 启动本地服务（docs 目录为根，可访问 site 与 ops）
python3 -m http.server 8765 --directory docs
```

浏览器打开：

| 页面 | URL |
| --- | --- |
| 文档首页 | http://localhost:8765/site/index.html |
| API 参考（Redoc） | http://localhost:8765/site/api/index.html |
| Runbook | http://localhost:8765/ops/RUNBOOK.md |
| 数据导出格式 | http://localhost:8765/ops/DATA_EXPORT_FORMAT.md |

> Markdown 链接在部分浏览器会直接下载；可用 VS Code Markdown Preview 或 mkdocs 渲染 ops 文档。

### 方式二：仅打开 API 页

生成后直接打开文件：

```bash
open docs/site/api/index.html   # macOS
```

Redoc 单页为自包含 HTML，无需 HTTP 服务。

### 方式三：Swagger UI 交互预览

```bash
./scripts/generate-api-docs.sh --swagger
python3 -m http.server 8765 --directory docs/site/api/swagger
# http://localhost:8765/index.html
```

## 部署建议

1. CI 在 `lint:contracts` 通过后执行 `./scripts/generate-api-docs.sh`。
2. 将 `docs/site/`（含生成的 `api/`）同步到内网静态托管（OSS / Nginx / GitLab Pages）。
3. 首页纯静态 HTML，目标首次加载 &lt; 1s（无外部 CDN 依赖）。

## 相关文档

- 契约 lint：`./scripts/contract-lint.sh`
- 运维 Runbook：`../ops/RUNBOOK.md`
- 数据导出格式：`../ops/DATA_EXPORT_FORMAT.md`
