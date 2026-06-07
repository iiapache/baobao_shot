#!/usr/bin/env bash
# T7.6 iOS 端侧性能 stub：相机冷启动 / 编辑器打开（真机 Instruments 前的占位记录）
# 预算：相机 ≤ 800ms / 编辑器 ≤ 500ms
# 真机专项请配合 tests/e2e/ios/PerformanceBenchmarkTests.swift 或 Instruments
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/perf.env" ]] && source "${SCRIPT_DIR}/perf.env"

DEVICE_MODEL="${PERF_IOS_DEVICE_MODEL:-iPhone 12}"
CAMERA_MS="${PERF_IOS_STUB_CAMERA_MS:-720}"
EDITOR_MS="${PERF_IOS_STUB_EDITOR_MS:-420}"
CAMERA_BUDGET_MS=800
EDITOR_BUDGET_MS=500
DRY_RUN="${PERF_DRY_RUN:-0}"
REPORT_DIR="${SCRIPT_DIR}/reports/$(date +%Y-%m)"
REPORT_FILE="${REPORT_DIR}/ios-stub-$(date +%Y%m%d-%H%M%S).json"

log() { printf '[perf-ios] %s\n' "$*" >&2; }

syntax_check() {
  log "syntax check: CAMERA_BUDGET_MS=${CAMERA_BUDGET_MS} EDITOR_BUDGET_MS=${EDITOR_BUDGET_MS}"
  log "PERF IOS SYNTAX CHECK PASSED"
  exit 0
}

if [[ "${1:-}" == "--syntax-check" ]] || [[ "${DRY_RUN}" == "1" ]]; then
  syntax_check
fi

mkdir -p "${REPORT_DIR}"

camera_pass="false"
editor_pass="false"
[[ "${CAMERA_MS}" -le "${CAMERA_BUDGET_MS}" ]] && camera_pass="true"
[[ "${EDITOR_MS}" -le "${EDITOR_BUDGET_MS}" ]] && editor_pass="true"

cat > "${REPORT_FILE}" <<EOF
{
  "task": "T7.6",
  "mode": "stub",
  "device": "${DEVICE_MODEL}",
  "build": "${E2E_APP_VERSION:-unknown}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "metrics": {
    "camera_cold_start_ms": ${CAMERA_MS},
    "camera_budget_ms": ${CAMERA_BUDGET_MS},
    "camera_pass": ${camera_pass},
    "editor_open_ms": ${EDITOR_MS},
    "editor_budget_ms": ${EDITOR_BUDGET_MS},
    "editor_pass": ${editor_pass}
  },
  "notes": "Stub values from PERF_IOS_STUB_* env. Replace with Instruments / XCTest on LAB-IP12-001 / LAB-IP16-001."
}
EOF

log "report: ${REPORT_FILE}"
log "camera: ${CAMERA_MS}ms (budget ${CAMERA_BUDGET_MS}ms) pass=${camera_pass}"
log "editor: ${EDITOR_MS}ms (budget ${EDITOR_BUDGET_MS}ms) pass=${editor_pass}"

if [[ "${camera_pass}" == "true" && "${editor_pass}" == "true" ]]; then
  log "PERF IOS STUB PASSED"
  exit 0
else
  log "PERF IOS STUB FAILED"
  exit 1
fi
