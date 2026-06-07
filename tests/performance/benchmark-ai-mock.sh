#!/usr/bin/env bash
# T7.6 AI 任务 mock 延迟统计：创建 → 轮询 succeeded 端到端耗时
# 预算：图像 P95 ≤ 60s / 视频 P95 ≤ 300s（5min）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/perf.env" ]] && source "${SCRIPT_DIR}/perf.env"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/../e2e/e2e.env" ]] && source "${SCRIPT_DIR}/../e2e/e2e.env"

BASE_URL="${BASE_URL:-http://localhost:18080}"
REGION="${E2E_REGION:-cn}"
APP_VERSION="${E2E_APP_VERSION:-1.0.0-staging}"
DEVICE_ID="${E2E_DEVICE_ID:-qa-device-iphone12-001}"
ADMIN_PHONE="${E2E_ADMIN_PHONE:-13800138001}"
ADMIN_CODE="${E2E_ADMIN_CODE:-123456}"
FAMILY_ID="${PERF_FAMILY_ID:-fam_e2e_001}"
INPUT_KEY="${PERF_AI_INPUT_KEY:-ai-tmp/usr_e2e_admin/e2e-input.heic}"

IMAGE_SAMPLES="${PERF_AI_IMAGE_SAMPLES:-10}"
VIDEO_SAMPLES="${PERF_AI_VIDEO_SAMPLES:-5}"
IMAGE_P95_BUDGET_SEC="${PERF_AI_IMAGE_P95_BUDGET_SEC:-60}"
VIDEO_P95_BUDGET_SEC="${PERF_AI_VIDEO_P95_BUDGET_SEC:-300}"
POLL_INTERVAL_SEC="${PERF_AI_POLL_INTERVAL_SEC:-1}"
POLL_MAX="${PERF_AI_POLL_MAX:-120}"
INJECT_DELAY_MS="${PERF_AI_INJECT_DELAY_MS:-0}"
DRY_RUN="${PERF_DRY_RUN:-0}"

CURL_OPTS=(-sS -w "\n%{http_code}" -H "Content-Type: application/json" \
  -H "X-Region: ${REGION}" \
  -H "X-App-Version: ${APP_VERSION}" \
  -H "X-Device-Id: ${DEVICE_ID}")

log() { printf '[perf-ai] %s\n' "$*" >&2; }

split_response() {
  HTTP_CODE=$(echo "$1" | tail -n1)
  BODY=$(echo "$1" | sed '$d')
}

json_field() {
  local body="$1" jq_path="$2"
  if command -v jq >/dev/null 2>&1; then
    echo "${body}" | jq -r "${jq_path} // empty"
  else
    echo ""
  fi
}

auth_login() {
  curl "${CURL_OPTS[@]}" -o /dev/null -X POST "${BASE_URL}/v1/auth/phone/code" \
    -d "{\"phone\":\"${ADMIN_PHONE}\"}" >/dev/null
  split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/login" \
    -d "{\"phone\":\"${ADMIN_PHONE}\",\"code\":\"${ADMIN_CODE}\"}")"
  if [[ "${HTTP_CODE}" != "200" ]]; then
    log "FAIL login HTTP ${HTTP_CODE}"
    exit 1
  fi
  local token
  token=$(json_field "${BODY}" '.data.accessToken')
  if [[ -z "${token}" ]]; then
    log "FAIL login: no accessToken"
    exit 1
  fi
  echo "${token}"
}

create_ai_task() {
  local token="$1" play="$2" duration="${3:-0}"
  local payload
  if [[ "${duration}" -gt 0 ]]; then
    payload=$(cat <<EOF
{"play":"${play}","inputObjectKey":"${INPUT_KEY}","familyId":"${FAMILY_ID}","params":{"duration":${duration},"aspectRatio":"1:1"}}
EOF
)
  else
    payload=$(cat <<EOF
{"play":"${play}","inputObjectKey":"${INPUT_KEY}","familyId":"${FAMILY_ID}","params":{"aspectRatio":"1:1"}}
EOF
)
  fi
  local curl_args=("${CURL_OPTS[@]}")
  [[ "${INJECT_DELAY_MS}" -gt 0 ]] && curl_args+=(-H "X-Perf-Delay-Ms: ${INJECT_DELAY_MS}")
  split_response "$(curl "${curl_args[@]}" \
    -H "Authorization: Bearer ${token}" \
    -X POST "${BASE_URL}/v1/ai/tasks" \
    -d "${payload}")"
  if [[ "${HTTP_CODE}" != "200" ]]; then
    log "FAIL aiCreateTask HTTP ${HTTP_CODE}"
    return 1
  fi
  json_field "${BODY}" '.data.taskId'
}

poll_task_elapsed_sec() {
  local token="$1" task_id="$2"
  local start end state i=0
  start=$(date +%s)
  while [[ "${i}" -lt "${POLL_MAX}" ]]; do
    split_response "$(curl "${CURL_OPTS[@]}" -H "Authorization: Bearer ${token}" \
      "${BASE_URL}/v1/ai/tasks/${task_id}")"
    if [[ "${HTTP_CODE}" != "200" ]]; then
      log "FAIL aiGetTask ${task_id} HTTP ${HTTP_CODE}"
      return 1
    fi
    state=$(json_field "${BODY}" '.data.state')
    case "${state}" in
      succeeded|failed|rejected|appealed|cancelled)
        end=$(date +%s)
        echo $((end - start))
        return 0
        ;;
    esac
    if [[ "${INJECT_DELAY_MS}" -gt 0 ]]; then
      sleep "$(awk -v ms="${INJECT_DELAY_MS}" 'BEGIN { printf "%.3f", ms / 1000 }')"
    else
      sleep "${POLL_INTERVAL_SEC}"
    fi
    i=$((i + 1))
  done
  log "FAIL poll ${task_id}: timeout"
  return 1
}

calc_p95() {
  local file="$1"
  local n idx
  n=$(wc -l < "${file}" | tr -d ' ')
  if [[ "${n}" -eq 0 ]]; then
    echo "0"
    return
  fi
  idx=$(awk -v n="${n}" 'BEGIN { print int((n - 1) * 0.95) + 1 }')
  sort -n "${file}" | sed -n "${idx}p"
}

run_samples() {
  local token="$1" play="$2" duration="$3" count="$4" out_file="$5" label="$6"
  local i task_id elapsed
  log "── ${label}: ${count} samples ──"
  for ((i = 0; i < count; i++)); do
    task_id=$(create_ai_task "${token}" "${play}" "${duration}") || return 1
    elapsed=$(poll_task_elapsed_sec "${token}" "${task_id}") || return 1
    echo "${elapsed}" >> "${out_file}"
    log "  sample $((i + 1))/${count}: ${elapsed}s taskId=${task_id}"
  done
}

syntax_check() {
  log "syntax check: bash -n OK"
  command -v curl >/dev/null 2>&1 || { log "FAIL: curl not found"; exit 1; }
  log "syntax check: IMAGE_SAMPLES=${IMAGE_SAMPLES} VIDEO_SAMPLES=${VIDEO_SAMPLES}"
  log "PERF AI SYNTAX CHECK PASSED"
  exit 0
}

if [[ "${1:-}" == "--syntax-check" ]] || [[ "${DRY_RUN}" == "1" ]]; then
  syntax_check
fi

log "Step 0: GET /health @ ${BASE_URL}"
health_code=$(curl -sS -o /dev/null -w "%{http_code}" "${BASE_URL}/health" || echo "000")
if [[ "${health_code}" != "200" ]]; then
  log "FAIL health HTTP ${health_code}"
  exit 1
fi

TOKEN="$(auth_login)"
IMG_SAMPLES_FILE="$(mktemp)"
VID_SAMPLES_FILE="$(mktemp)"
trap 'rm -f "${IMG_SAMPLES_FILE}" "${VID_SAMPLES_FILE}"' EXIT

run_samples "${TOKEN}" "ghibli_kid" 0 "${IMAGE_SAMPLES}" "${IMG_SAMPLES_FILE}" "AI image (ghibli_kid)"
run_samples "${TOKEN}" "video_walk" 5 "${VIDEO_SAMPLES}" "${VID_SAMPLES_FILE}" "AI video 5s (video_walk)"

IMG_P95=$(calc_p95 "${IMG_SAMPLES_FILE}")
VID_P95=$(calc_p95 "${VID_SAMPLES_FILE}")

log "── AI latency summary ──"
log "image P95=${IMG_P95}s (budget ≤ ${IMAGE_P95_BUDGET_SEC}s)"
log "video P95=${VID_P95}s (budget ≤ ${VIDEO_P95_BUDGET_SEC}s)"

fail=0
if [[ "${IMG_P95}" -gt "${IMAGE_P95_BUDGET_SEC}" ]]; then
  log "FAIL image P95 ${IMG_P95}s > ${IMAGE_P95_BUDGET_SEC}s"
  fail=1
fi
if [[ "${VID_P95}" -gt "${VIDEO_P95_BUDGET_SEC}" ]]; then
  log "FAIL video P95 ${VID_P95}s > ${VIDEO_P95_BUDGET_SEC}s"
  fail=1
fi

if [[ "${fail}" -eq 0 ]]; then
  log "PERF AI PASSED"
  exit 0
else
  log "PERF AI FAILED"
  exit 1
fi
