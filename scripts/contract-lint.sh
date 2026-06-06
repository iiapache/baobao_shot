#!/usr/bin/env bash
# OpenAPI + protobuf 契约 lint / breaking change 检查
# 用法:
#   ./scripts/contract-lint.sh              # lint only
#   ./scripts/contract-lint.sh --breaking   # lint + breaking change（需 git）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENAPI_DIR="${ROOT}/contracts/openapi"
PROTO_DIR="${ROOT}/contracts/protobuf"
OPENAPI_ENTRY="${OPENAPI_DIR}/openapi.yaml"
OPENAPI_BUNDLE="${OPENAPI_DIR}/openapi.bundle.yaml"
SPECTRAL_RULESET="${OPENAPI_DIR}/.spectral.yaml"
CHECK_BREAKING=false

for arg in "$@"; do
  case "$arg" in
    --breaking) CHECK_BREAKING=true ;;
    -h|--help)
      echo "usage: $0 [--breaking]"
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

ensure_oasdiff() {
  if command -v oasdiff >/dev/null 2>&1; then
    return
  fi
  local ver="1.10.21"
  local os arch url tmp
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) echo "error: 不支持的架构 $arch" >&2; exit 1 ;;
  esac
  url="https://github.com/Tufin/oasdiff/releases/download/v${ver}/oasdiff_${ver}_${os}_${arch}.tar.gz"
  log "下载 oasdiff v${ver} ..."
  tmp="$(mktemp -d)"
  curl -fsSL "$url" | tar -xz -C "$tmp"
  chmod +x "${tmp}/oasdiff"
  export PATH="${tmp}:${PATH}"
}

bundle_openapi() {
  log "bundle OpenAPI -> ${OPENAPI_BUNDLE}"
  npx --yes @redocly/cli bundle "$OPENAPI_ENTRY" -o "$OPENAPI_BUNDLE" --ext yaml
}

lint_openapi() {
  bundle_openapi
  log "Spectral lint"
  npx --yes @stoplight/spectral-cli lint "$OPENAPI_BUNDLE" --ruleset "$SPECTRAL_RULESET" --fail-severity error
}

lint_protobuf() {
  log "buf lint (protobuf)"
  require_cmd buf
  make -C "$PROTO_DIR" lint
}

check_openapi_breaking() {
  require_cmd git
  local base_ref="${CONTRACT_BASE_REF:-origin/main}"
  local tmp_base
  tmp_base="$(mktemp)"
  log "OpenAPI breaking change: ${base_ref}..HEAD"
  git fetch origin main 2>/dev/null || true
  if git show "${base_ref}:contracts/openapi/openapi.yaml" >/dev/null 2>&1; then
    git show "${base_ref}:contracts/openapi/openapi.yaml" > "${tmp_base}.yaml"
    ensure_oasdiff
    bundle_openapi
    if git show "${base_ref}:contracts/openapi/openapi.bundle.yaml" >/dev/null 2>&1; then
      git show "${base_ref}:contracts/openapi/openapi.bundle.yaml" > "${tmp_base}.bundle.yaml"
      oasdiff breaking "${tmp_base}.bundle.yaml" "$OPENAPI_BUNDLE"
    else
      oasdiff breaking "${tmp_base}.yaml" "$OPENAPI_ENTRY"
    fi
  else
    log "基线分支无 openapi.yaml，跳过 OpenAPI breaking check（首次引入）"
  fi
  rm -f "${tmp_base}.yaml" "${tmp_base}.bundle.yaml"
}

check_protobuf_breaking() {
  require_cmd git
  require_cmd buf
  log "protobuf breaking change (buf)"
  git fetch origin main 2>/dev/null || true
  make -C "$PROTO_DIR" breaking || {
    log "protobuf breaking: 首次引入或无 main 基线时可忽略"
  }
}

main() {
  cd "$ROOT"
  test -f "$OPENAPI_ENTRY"
  test -d "$PROTO_DIR/proto"

  lint_openapi
  lint_protobuf

  if [[ "$CHECK_BREAKING" == true ]]; then
    check_openapi_breaking
    check_protobuf_breaking
  fi

  log "contract lint OK"
}

main "$@"
