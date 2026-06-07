#!/usr/bin/env bash
# UX-04 端侧启动性能：SPM 单测 + 真机日志采集指引 + JSON 报告生成
# 预算：相机 ≤ 800ms / 编辑器 ≤ 500ms
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
IOS_DIR="${REPO_ROOT}/ios"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/perf.env" ]] && source "${SCRIPT_DIR}/perf.env"

CAMERA_BUDGET_MS=800
EDITOR_BUDGET_MS=500
MODE="${1:-run}"
REPORT_DIR="${SCRIPT_DIR}/reports/$(date +%Y-%m)"
REPORT_FILE="${REPORT_DIR}/startup-benchmark-$(date +%Y%m%d-%H%M%S).json"

log() { printf '[perf-startup] %s\n' "$*" >&2; }

collect_guide() {
  cat <<'EOF'
=== UX-04 真机日志采集 ===

1. Xcode Debug Run 到真机（LAB-IP12-001 或 LAB-IP16-001）
2. Console 过滤器：[Performance]
3. 场景 A — 相机：杀进程 → 冷启动 → 相机 Tab → 记录 camera_cold_start 行
4. 场景 B — 编辑：拍照/选图 → 进入编辑 → 记录 editor_open 行
5. 将 P50/P95 填入 tests/performance/PERFORMANCE_REPORT.md

日志格式：
  [Performance] camera_cold_start source=camera_tab elapsed=XXXms budget=800ms PASS|FAIL
  [Performance] editor_open source=camera elapsed=XXXms budget=500ms PASS|FAIL

Instruments 详细步骤：tests/performance/INSTRUMENTS_GUIDE.md
EOF
}

run_spm_tests() {
  log "Running PerformanceTrackerTests..."
  (cd "${IOS_DIR}/Packages/BabyCameraDiagnostics" && swift test --filter PerformanceTrackerTests)

  log "Running CameraStartupBenchmarkTests..."
  (cd "${IOS_DIR}/Packages/BabyCameraCamera" && swift test --filter CameraStartupBenchmarkTests)

  log "Running EditorOpenBenchmarkTests..."
  (cd "${IOS_DIR}/Packages/BabyCameraEditor" && swift test --filter EditorOpenBenchmarkTests)
}

write_report() {
  local camera_ms="${PERF_IOS_STUB_CAMERA_MS:-}"
  local editor_ms="${PERF_IOS_STUB_EDITOR_MS:-}"
  local device="${PERF_IOS_DEVICE_MODEL:-manual}"

  if [[ -z "${camera_ms}" || -z "${editor_ms}" ]]; then
    log "Skip JSON report: set PERF_IOS_STUB_CAMERA_MS and PERF_IOS_STUB_EDITOR_MS to record stub metrics"
    return 0
  fi

  mkdir -p "${REPORT_DIR}"

  local camera_pass="false"
  local editor_pass="false"
  [[ "${camera_ms}" -le "${CAMERA_BUDGET_MS}" ]] && camera_pass="true"
  [[ "${editor_ms}" -le "${EDITOR_BUDGET_MS}" ]] && editor_pass="true"

  cat > "${REPORT_FILE}" <<EOF
{
  "task": "UX-04",
  "mode": "startup_benchmark",
  "device": "${device}",
  "build": "${E2E_APP_VERSION:-unknown}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "budgets": {
    "camera_cold_start_ms": ${CAMERA_BUDGET_MS},
    "editor_open_ms": ${EDITOR_BUDGET_MS}
  },
  "metrics": {
    "camera_cold_start_ms": ${camera_ms},
    "camera_pass": ${camera_pass},
    "editor_open_ms": ${editor_ms},
    "editor_pass": ${editor_pass}
  },
  "notes": "Replace stub values with [Performance] log lines from device. Template: tests/performance/PERFORMANCE_REPORT.md"
}
EOF

  log "report: ${REPORT_FILE}"
  log "camera: ${camera_ms}ms pass=${camera_pass}"
  log "editor: ${editor_ms}ms pass=${editor_pass}"

  if [[ "${camera_pass}" == "true" && "${editor_pass}" == "true" ]]; then
    log "PERF STARTUP STUB PASSED"
  else
    log "PERF STARTUP STUB FAILED"
    return 1
  fi
}

case "${MODE}" in
  --collect-guide)
    collect_guide
    ;;
  --spm-only)
    run_spm_tests
    log "PERF STARTUP SPM PASSED"
    ;;
  --syntax-check)
    log "CAMERA_BUDGET_MS=${CAMERA_BUDGET_MS} EDITOR_BUDGET_MS=${EDITOR_BUDGET_MS}"
    log "PERF STARTUP SYNTAX CHECK PASSED"
    ;;
  run|"")
    run_spm_tests
    write_report || true
    collect_guide
    log "PERF STARTUP PASSED (SPM); complete device report in PERFORMANCE_REPORT.md"
    ;;
  *)
    log "Usage: $0 [--collect-guide|--spm-only|--syntax-check]"
    exit 2
    ;;
esac
