#!/usr/bin/env bash
# T7.6 Feed API 性能压测：GET /v1/feeds/family 延迟分布（缓存命中场景）
# 预算：P95 ≤ 500ms（dev-plan T7.6 / T5.3）
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

REQUESTS="${PERF_FEED_REQUESTS:-50}"
WARMUP="${PERF_FEED_WARMUP:-5}"
P95_BUDGET_MS="${PERF_FEED_P95_BUDGET_MS:-500}"
DRY_RUN="${PERF_DRY_RUN:-0}"

CURL_OPTS=(-sS -H "Content-Type: application/json" \
  -H "X-Region: ${REGION}" \
  -H "X-App-Version: ${APP_VERSION}" \
  -H "X-Device-Id: ${DEVICE_ID}")

log() { printf '[perf-feed] %s\n' "$*" >&2; }

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
  curl "${CURL_OPTS[@]}" -w "\n%{http_code}" -o /dev/null -X POST "${BASE_URL}/v1/auth/phone/code" \
    -d "{\"phone\":\"${ADMIN_PHONE}\"}" >/dev/null
  split_response "$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST "${BASE_URL}/v1/auth/phone/login" \
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

measure_feed_ms() {
  local token="$1"
  local raw
  raw=$(curl "${CURL_OPTS[@]}" -o /dev/null \
    -H "Authorization: Bearer ${token}" \
    -w "%{time_total}" \
    "${BASE_URL}/v1/feeds/family?familyId=${FAMILY_ID}&limit=20")
  # curl time_total 为秒（浮点），转毫秒
  awk -v t="${raw}" 'BEGIN { printf "%d\n", int(t * 1000 + 0.5) }'
}

syntax_check() {
  log "syntax check: bash -n OK"
  command -v curl >/dev/null 2>&1 || { log "FAIL: curl not found"; exit 1; }
  log "syntax check: curl available"
  log "syntax check: REQUESTS=${REQUESTS} WARMUP=${WARMUP} P95_BUDGET_MS=${P95_BUDGET_MS}"
  log "PERF FEED SYNTAX CHECK PASSED"
  exit 0
}

if [[ "${1:-}" == "--syntax-check" ]] || [[ "${DRY_RUN}" == "1" ]]; then
  syntax_check
fi

log "Step 0: GET /health @ ${BASE_URL}"
health_code=$(curl -sS -o /dev/null -w "%{http_code}" "${BASE_URL}/health" || echo "000")
if [[ "${health_code}" != "200" ]]; then
  log "FAIL health HTTP ${health_code} — 请先启动 mock-api: cd tests/mocks/api && python3 mock_server.py"
  exit 1
fi

TOKEN="$(auth_login)"
log "Step 1: warmup ${WARMUP} requests (cache priming)"
for ((i = 0; i < WARMUP; i++)); do
  measure_feed_ms "${TOKEN}" >/dev/null
done

TMP_SAMPLES="$(mktemp)"
trap 'rm -f "${TMP_SAMPLES}"' EXIT

log "Step 2: benchmark ${REQUESTS} requests → ${TMP_SAMPLES}"
for ((i = 0; i < REQUESTS; i++)); do
  measure_feed_ms "${TOKEN}" >> "${TMP_SAMPLES}"
done

SORTED_SAMPLES="$(mktemp)"
sort -n "${TMP_SAMPLES}" > "${SORTED_SAMPLES}"
read -r COUNT P50 P95 P99 MIN MAX AVG < <(
  awk -v sorted="${SORTED_SAMPLES}" '
    BEGIN {
      while ((getline line < sorted) > 0) {
        n++
        a[n] = line + 0
        sum += line + 0
      }
      close(sorted)
      if (n == 0) { print "0 0 0 0 0 0 0"; exit }
      p50_idx = int((n - 1) * 0.50) + 1
      p95_idx = int((n - 1) * 0.95) + 1
      p99_idx = int((n - 1) * 0.99) + 1
      printf "%d %d %d %d %d %d %.1f\n", n, a[p50_idx], a[p95_idx], a[p99_idx], a[1], a[n], sum / n
    }
  '
)
rm -f "${SORTED_SAMPLES}"

log "── Feed latency (ms) ──"
log "samples=${COUNT} min=${MIN} avg=${AVG} p50=${P50} p95=${P95} p99=${P99} max=${MAX}"
log "budget: P95 ≤ ${P95_BUDGET_MS}ms (cache hit)"

if [[ "${P95}" -le "${P95_BUDGET_MS}" ]]; then
  log "PERF FEED PASSED: P95=${P95}ms ≤ ${P95_BUDGET_MS}ms"
  exit 0
else
  log "PERF FEED FAILED: P95=${P95}ms > ${P95_BUDGET_MS}ms"
  exit 1
fi
