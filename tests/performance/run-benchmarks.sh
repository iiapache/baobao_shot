#!/usr/bin/env bash
# T7.6 一键跑性能基准：Feed + AI mock + iOS stub + UX-04 启动 SPM
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run() {
  local script="$1"
  log "── $(basename "${script}") ──"
  bash "${script}"
}

log() { printf '[perf-all] %s\n' "$*" >&2; }

if [[ "${1:-}" == "--syntax-check" ]]; then
  export PERF_DRY_RUN=1
  bash "${SCRIPT_DIR}/benchmark-feed.sh" --syntax-check
  bash "${SCRIPT_DIR}/benchmark-ai-mock.sh" --syntax-check
  bash "${SCRIPT_DIR}/benchmark-ios-device.sh" --syntax-check
  bash "${SCRIPT_DIR}/benchmark-ios-startup.sh" --syntax-check
  log "PERF ALL SYNTAX CHECK PASSED"
  exit 0
fi

run "${SCRIPT_DIR}/benchmark-feed.sh"
run "${SCRIPT_DIR}/benchmark-ai-mock.sh"
run "${SCRIPT_DIR}/benchmark-ios-device.sh"
run "${SCRIPT_DIR}/benchmark-ios-startup.sh" --spm-only

log "PERF ALL PASSED"
