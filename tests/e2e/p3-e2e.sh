#!/usr/bin/env bash
# P3 AI E2E（T3.26）：图像 happy / ModelFailed / Rejected+申诉 / 视频 5s·10s / 弱网·切后台 mock
# 对齐 ai-dispatch-svc · contracts/openapi §6 · tests/mocks/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/e2e.env" ]] && source "${SCRIPT_DIR}/e2e.env"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/p3-ai.env" ]] && source "${SCRIPT_DIR}/p3-ai.env"

BASE_URL="${BASE_URL:-http://localhost:18080}"
REGION="${E2E_REGION:-cn}"
APP_VERSION="${E2E_APP_VERSION:-1.0.0-staging}"
DEVICE_ID="${E2E_DEVICE_ID:-qa-device-iphone12-001}"
ADMIN_PHONE="${E2E_ADMIN_PHONE:-13800138001}"
ADMIN_CODE="${E2E_ADMIN_CODE:-123456}"
FAMILY_ID="${P3_FAMILY_ID:-fam_e2e_001}"
INPUT_KEY="${P3_INPUT_OBJECT_KEY:-ai-tmp/usr_e2e_admin/e2e-input.heic}"

IMAGE_SLA_SEC="${P3_IMAGE_SLA_SEC:-60}"
VIDEO_SLA_SEC="${P3_VIDEO_SLA_SEC:-300}"
POLL_INTERVAL_SEC="${P3_POLL_INTERVAL_SEC:-1}"
POLL_MAX="${P3_POLL_MAX:-15}"

CURL_OPTS=(-sS -w "\n%{http_code}" -H "Content-Type: application/json" \
  -H "X-Region: ${REGION}" \
  -H "X-App-Version: ${APP_VERSION}" \
  -H "X-Device-Id: ${DEVICE_ID}")

pass=0
fail=0

log() { printf '[p3-e2e] %s\n' "$*" >&2; }

assert_http() {
  local step="$1" expected="$2" actual="$3"
  if [[ "${actual}" == "${expected}" ]]; then
    log "PASS ${step} (HTTP ${actual})"
    pass=$((pass + 1))
  else
    log "FAIL ${step} expected HTTP ${expected}, got ${actual}"
    fail=$((fail + 1))
  fi
}

assert_body_contains() {
  local step="$1" needle="$2" body="$3"
  if echo "${body}" | grep -qE "${needle}"; then
    log "PASS ${step} (body match)"
    pass=$((pass + 1))
  else
    log "FAIL ${step} body missing pattern '${needle}'"
    echo "${body}" | head -c 500
    fail=$((fail + 1))
  fi
}

assert_sla() {
  local step="$1" elapsed="$2" budget="$3"
  if awk "BEGIN {exit !(${elapsed} <= ${budget})}"; then
    log "PASS ${step} (elapsed ${elapsed}s ≤ ${budget}s SLA)"
    pass=$((pass + 1))
  else
    log "FAIL ${step} elapsed ${elapsed}s exceeds SLA ${budget}s"
    fail=$((fail + 1))
  fi
}

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
  log "Step: POST /v1/auth/phone/login"
  split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/code" \
    -d "{\"phone\":\"${ADMIN_PHONE}\"}")"
  assert_http "authPhoneSendCode" "200" "${HTTP_CODE}"

  split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/login" \
    -d "{\"phone\":\"${ADMIN_PHONE}\",\"code\":\"${ADMIN_CODE}\"}")"
  assert_http "authPhoneLogin" "200" "${HTTP_CODE}"
  local token
  token=$(json_field "${BODY}" '.data.accessToken')
  [[ -n "${token}" ]] || { log "FAIL login: no accessToken"; fail=$((fail + 1)); echo ""; return; }
  echo "${token}"
}

poll_task_until_terminal() {
  local token="$1" task_id="$2" out_var="$3"
  local i=0 state=""
  while [[ "${i}" -lt "${POLL_MAX}" ]]; do
    split_response "$(curl "${CURL_OPTS[@]}" -H "Authorization: Bearer ${token}" \
      "${BASE_URL}/v1/ai/tasks/${task_id}")"
    assert_http "aiGetTask ${task_id} poll $((i + 1))" "200" "${HTTP_CODE}"
    state=$(json_field "${BODY}" '.data.state')
    case "${state}" in
      succeeded|failed|rejected|appealed|cancelled)
        printf -v "${out_var}" '%s' "${BODY}"
        return 0
        ;;
    esac
    sleep "${POLL_INTERVAL_SEC}"
    i=$((i + 1))
  done
  log "FAIL poll ${task_id}: timeout after ${POLL_MAX} attempts (last state=${state})"
  fail=$((fail + 1))
  printf -v "${out_var}" '%s' "${BODY}"
  return 1
}

create_ai_task() {
  local token="$1" play="$2" duration="${3:-0}" scenario="${4:-}" network="${5:-}"
  local curl_args=("${CURL_OPTS[@]}")
  [[ -n "${scenario}" ]] && curl_args+=(-H "X-E2E-Scenario: ${scenario}")
  [[ -n "${network}" ]] && curl_args+=(-H "X-E2E-Network: ${network}")

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

  split_response "$(curl "${curl_args[@]}" \
    -H "Authorization: Bearer ${token}" \
    -X POST "${BASE_URL}/v1/ai/tasks" \
    -d "${payload}")"
  assert_http "aiCreateTask ${play}" "200" "${HTTP_CODE}"
  echo "${BODY}"
}

# ── 前置：健康检查 + 登录 ────────────────────────────────────
log "Step 0: GET /health @ ${BASE_URL}"
split_response "$(curl "${CURL_OPTS[@]}" "${BASE_URL}/health")"
assert_http "health" "200" "${HTTP_CODE}"

TOKEN="$(auth_login)"
AUTH=(-H "Authorization: Bearer ${TOKEN}")

# ── 玩法目录 ─────────────────────────────────────────────────
log "Step 1: GET /v1/ai/plays (aiListPlays)"
split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" "${BASE_URL}/v1/ai/plays")"
assert_http "aiListPlays" "200" "${HTTP_CODE}"
assert_body_contains "aiListPlays ghibli_kid" 'ghibli_kid' "${BODY}"
assert_body_contains "aiListPlays video_walk" 'video_walk' "${BODY}"

# ── 上传 AI 输入（STS 直传 mock）──────────────────────────────
log "Step 2: POST /v1/uploads/init (purpose=ai-input)"
split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" -X POST "${BASE_URL}/v1/uploads/init" \
  -d "{\"purpose\":\"ai-input\",\"familyId\":\"${FAMILY_ID}\",\"items\":[{\"clientRef\":\"ai-ref-1\",\"kind\":\"photo\",\"mime\":\"image/heic\",\"size\":2048}]}")"
assert_http "uploadInit ai-input" "200" "${HTTP_CODE}"

# ── 场景 A：图像 happy path ───────────────────────────────────
log "── Scenario A: Image Happy Path ──"
START_A=$(date +%s)
CREATE_A=$(create_ai_task "${TOKEN}" "ghibli_kid")
TASK_A=$(json_field "${CREATE_A}" '.data.taskId')
[[ -n "${TASK_A}" ]] || TASK_A="tsk_e2e_img_happy"
assert_body_contains "happy create taskId" 'taskId' "${CREATE_A}"

POLL_A=""
poll_task_until_terminal "${TOKEN}" "${TASK_A}" POLL_A || true
assert_body_contains "happy succeeded" '"state"[[:space:]]*:[[:space:]]*"succeeded"' "${POLL_A}"
assert_body_contains "happy resultUrl" 'resultUrl' "${POLL_A}"
assert_body_contains "happy deepSynth" 'deepSynth' "${POLL_A}"
END_A=$(date +%s)
assert_sla "image happy SLA" "$((END_A - START_A))" "${IMAGE_SLA_SEC}"

# ── 场景 B：ModelFailed ───────────────────────────────────────
log "── Scenario B: ModelFailed ──"
CREATE_B=$(create_ai_task "${TOKEN}" "ghibli_kid" 0 "model_failed")
TASK_B=$(json_field "${CREATE_B}" '.data.taskId')
[[ -n "${TASK_B}" ]] || TASK_B="tsk_e2e_model_failed"

POLL_B=""
poll_task_until_terminal "${TOKEN}" "${TASK_B}" POLL_B || true
assert_body_contains "model_failed state" '"state"[[:space:]]*:[[:space:]]*"failed"' "${POLL_B}"
assert_body_contains "model_failed refund hint" 'failureReason' "${POLL_B}"

# ── 场景 C：Rejected + Appeal ─────────────────────────────────
log "── Scenario C: Rejected + Appeal ──"
CREATE_C=$(create_ai_task "${TOKEN}" "ghibli_kid" 0 "rejected")
TASK_C=$(json_field "${CREATE_C}" '.data.taskId')
[[ -n "${TASK_C}" ]] || TASK_C="tsk_e2e_rejected"

POLL_C=""
poll_task_until_terminal "${TOKEN}" "${TASK_C}" POLL_C || true
assert_body_contains "rejected state" '"state"[[:space:]]*:[[:space:]]*"rejected"' "${POLL_C}"

log "Step: POST /v1/ai/tasks/${TASK_C}/appeal (aiAppealTask)"
split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" \
  -X POST "${BASE_URL}/v1/ai/tasks/${TASK_C}/appeal" \
  -d '{"reason":"E2E误判申诉"}')"
assert_http "aiAppealTask" "200" "${HTTP_CODE}"
assert_body_contains "appeal state appealed" '"state"[[:space:]]*:[[:space:]]*"appealed"' "${BODY}"
assert_body_contains "appealId" 'appealId' "${BODY}"

# ── 场景 D：视频 5s ───────────────────────────────────────────
log "── Scenario D: Video 5s ──"
START_D=$(date +%s)
CREATE_D=$(create_ai_task "${TOKEN}" "video_walk" 5)
TASK_D=$(json_field "${CREATE_D}" '.data.taskId')
[[ -n "${TASK_D}" ]] || TASK_D="tsk_e2e_vid_5s"
assert_body_contains "video 5s costCredits 60" '"costCredits"[[:space:]]*:[[:space:]]*60' "${CREATE_D}"

POLL_D=""
poll_task_until_terminal "${TOKEN}" "${TASK_D}" POLL_D || true
assert_body_contains "video 5s succeeded" '"state"[[:space:]]*:[[:space:]]*"succeeded"' "${POLL_D}"
assert_body_contains "video 5s mp4" '\.mp4' "${POLL_D}"
END_D=$(date +%s)
assert_sla "video 5s SLA" "$((END_D - START_D))" "${VIDEO_SLA_SEC}"

# ── 场景 E：视频 10s ──────────────────────────────────────────
log "── Scenario E: Video 10s ──"
START_E=$(date +%s)
CREATE_E=$(create_ai_task "${TOKEN}" "video_walk" 10)
TASK_E=$(json_field "${CREATE_E}" '.data.taskId')
[[ -n "${TASK_E}" ]] || TASK_E="tsk_e2e_vid_10s"
assert_body_contains "video 10s costCredits 120" '"costCredits"[[:space:]]*:[[:space:]]*120' "${CREATE_E}"

POLL_E=""
poll_task_until_terminal "${TOKEN}" "${TASK_E}" POLL_E || true
assert_body_contains "video 10s succeeded" '"state"[[:space:]]*:[[:space:]]*"succeeded"' "${POLL_E}"
assert_body_contains "video 10s mp4" '\.mp4' "${POLL_E}"
END_E=$(date +%s)
assert_sla "video 10s SLA" "$((END_E - START_E))" "${VIDEO_SLA_SEC}"

# ── 场景 F：弱网 mock（多轮轮询）──────────────────────────────
log "── Scenario F: Slow Network (mock poll) ──"
CREATE_F=$(create_ai_task "${TOKEN}" "ghibli_kid" 0 "" "slow")
TASK_F=$(json_field "${CREATE_F}" '.data.taskId')
[[ -n "${TASK_F}" ]] || TASK_F="tsk_e2e_slow_net"

POLL_F=""
poll_task_until_terminal "${TOKEN}" "${TASK_F}" POLL_F || true
assert_body_contains "slow net succeeded" '"state"[[:space:]]*:[[:space:]]*"succeeded"' "${POLL_F}"

# ── 场景 G：切后台 mock（创建即 running → 轮询成功）──────────
log "── Scenario G: Background (mock push compensation) ──"
CREATE_G=$(create_ai_task "${TOKEN}" "ghibli_kid" 0 "background")
TASK_G=$(json_field "${CREATE_G}" '.data.taskId')
[[ -n "${TASK_G}" ]] || TASK_G="tsk_e2e_background"
assert_body_contains "background initial running" '"state"[[:space:]]*:[[:space:]]*"running"' "${CREATE_G}"

POLL_G=""
poll_task_until_terminal "${TOKEN}" "${TASK_G}" POLL_G || true
assert_body_contains "background poll succeeded" '"state"[[:space:]]*:[[:space:]]*"succeeded"' "${POLL_G}"

# ── 汇总 ─────────────────────────────────────────────────────
log "────────────────────────────────────"
log "Results: ${pass} passed assertions, ${fail} failed"
if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi
log "P3 AI E2E PASSED: image happy · model_failed · rejected+appeal · video 5s/10s · slow · background"
exit 0
