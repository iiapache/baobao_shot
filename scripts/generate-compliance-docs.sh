#!/usr/bin/env bash
# 从 compliance/policies/*.md 生成 docs/compliance/legal 静态页（COMP-02）
#
# 用法:
#   ./scripts/generate-compliance-docs.sh
#   ./scripts/generate-compliance-docs.sh --check   # 仅校验源文件存在
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${ROOT}/compliance/policies"
OUTPUT_ROOT="${ROOT}/docs/compliance/legal"

CHECK_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=true ;;
    -h|--help)
      sed -n '2,7p' "$0"
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

log() { echo ">>> $*"; }

required=(
  privacy-policy-cn.md
  privacy-policy-os.md
  terms-of-service.md
  deep-synthesis-notice.md
  third-party-sdk-list.md
)

for name in "${required[@]}"; do
  if [[ ! -f "${SOURCE_DIR}/${name}" ]]; then
    echo "error: missing ${SOURCE_DIR}/${name}" >&2
    exit 1
  fi
done

if [[ "${CHECK_ONLY}" == true ]]; then
  log "compliance source files OK"
  exit 0
fi

log "generate compliance HTML -> ${OUTPUT_ROOT}"
python3 "${ROOT}/scripts/generate-compliance-docs.py"
