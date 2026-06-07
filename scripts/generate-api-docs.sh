#!/usr/bin/env bash
# 从 contracts/openapi 生成静态 API 文档（T7.18）
#
# 用法:
#   ./scripts/generate-api-docs.sh              # 生成 Redoc HTML
#   ./scripts/generate-api-docs.sh --swagger  # 额外生成 Swagger UI 静态页
#   ./scripts/generate-api-docs.sh --check      # 仅校验 bundle，不输出 HTML
#
# 产出:
#   docs/site/api/index.html          # Redoc 单页（默认）
#   docs/site/api/swagger/index.html  # Swagger UI（--swagger）
#   contracts/openapi/openapi.bundle.yaml  # bundle（与 contract-lint 共用）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENAPI_DIR="${ROOT}/contracts/openapi"
OPENAPI_ENTRY="${OPENAPI_DIR}/openapi.yaml"
OPENAPI_BUNDLE="${OPENAPI_DIR}/openapi.bundle.yaml"
OUTPUT_DIR="${ROOT}/docs/site/api"
REDOC_HTML="${OUTPUT_DIR}/index.html"
SWAGGER_DIR="${OUTPUT_DIR}/swagger"

GENERATE_SWAGGER=false
CHECK_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --swagger) GENERATE_SWAGGER=true ;;
    --check) CHECK_ONLY=true ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

log() { echo ">>> $*"; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: $1 未安装" >&2
    exit 1
  fi
}

bundle_openapi() {
  log "bundle OpenAPI -> ${OPENAPI_BUNDLE}"
  npx --yes @redocly/cli bundle "$OPENAPI_ENTRY" -o "$OPENAPI_BUNDLE" --ext yaml
}

build_redoc_html() {
  mkdir -p "$OUTPUT_DIR"
  log "build Redoc HTML -> ${REDOC_HTML}"
  npx --yes @redocly/cli build-docs "$OPENAPI_BUNDLE" \
    -o "$REDOC_HTML" \
    --title "BabyCamera API（内部）"
}

build_swagger_ui() {
  require_cmd curl
  mkdir -p "${SWAGGER_DIR}"
  log "download Swagger UI dist -> ${SWAGGER_DIR}"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL "https://registry.npmjs.org/swagger-ui-dist/-/swagger-ui-dist-5.17.14.tgz" \
    | tar -xz -C "$tmp" --strip-components=1 package

  cp -R "${tmp}/." "${SWAGGER_DIR}/"
  cp "$OPENAPI_BUNDLE" "${SWAGGER_DIR}/openapi.yaml"

  cat > "${SWAGGER_DIR}/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>BabyCamera API — Swagger UI</title>
  <link rel="stylesheet" href="swagger-ui.css" />
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="swagger-ui-bundle.js"></script>
  <script src="swagger-ui-standalone-preset.js"></script>
  <script>
    window.onload = function () {
      SwaggerUIBundle({
        url: "openapi.yaml",
        dom_id: "#swagger-ui",
        presets: [SwaggerUIBundle.presets.apis, SwaggerUIStandalonePreset],
        layout: "StandaloneLayout",
        deepLinking: true,
      });
    };
  </script>
</body>
</html>
EOF
  log "Swagger UI -> ${SWAGGER_DIR}/index.html"
}

main() {
  require_cmd npx
  bundle_openapi

  if [[ "$CHECK_ONLY" == true ]]; then
    log "check only: bundle OK"
    exit 0
  fi

  build_redoc_html

  if [[ "$GENERATE_SWAGGER" == true ]]; then
    build_swagger_ui
  fi

  log "done"
  log "  Redoc:   file://${REDOC_HTML}"
  if [[ "$GENERATE_SWAGGER" == true ]]; then
    log "  Swagger: file://${SWAGGER_DIR}/index.html"
  fi
}

main "$@"
