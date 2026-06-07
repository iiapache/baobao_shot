#!/usr/bin/env bash
# T7.12 关键路径冒烟：登录 → 家庭(P1) → 发布 mock(P0) → AI mock(P3) → Feed(P5)
# 整合 p1/p3/p5 子集；门禁：≥30 断言
# 前置：tests/mocks mock-api @ localhost:18080
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/e2e.env" ]] && source "${SCRIPT_DIR}/e2e.env"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/smoke-critical-path.env" ]] && source "${SCRIPT_DIR}/smoke-critical-path.env"

BASE_URL="${BASE_URL:-http://localhost:18080}"
REGION="${E2E_REGION:-cn}"
APP_VERSION="${E2E_APP_VERSION:-1.0.0-staging}"
DEVICE_ID="${E2E_DEVICE_ID:-qa-device-iphone12-001}"
MEMBER_DEVICE_ID="${E2E_MEMBER_DEVICE_ID:-qa-device-iphone12-002}"
ADMIN_PHONE="${E2E_ADMIN_PHONE:-13800138001}"
ADMIN_CODE="${E2E_ADMIN_CODE:-123456}"
MEMBER_PHONE="${E2E_MEMBER_PHONE:-13800138002}"
MEMBER_CODE="${E2E_MEMBER_CODE:-123456}"
INPUT_KEY="${SMOKE_AI_INPUT_KEY:-ai-tmp/usr_e2e_admin/e2e-input.heic}"
POLL_INTERVAL_SEC="${SMOKE_POLL_INTERVAL_SEC:-1}"
POLL_MAX="${SMOKE_POLL_MAX:-15}"
CURL_RESOLVE="${STAGING_RESOLVE:-}"

CURL_OPTS=(-sS -w "\n%{http_code}" -H "Content-Type: application/json" \
  -H "X-Region: ${REGION}" \
  -H "X-App-Version: ${APP_VERSION}" \
  -H "X-Device-Id: ${DEVICE_ID}")

MEMBER_CURL_OPTS=(-sS -w "\n%{http_code}" -H "Content-Type: application/json" \
  -H "X-Region: ${REGION}" \
  -H "X-App-Version: ${APP_VERSION}" \
  -H "X-Device-Id: ${MEMBER_DEVICE_ID}")

if [[ -n "${CURL_RESOLVE}" ]]; then
  CURL_OPTS+=(--resolve "${CURL_RESOLVE}")
  MEMBER_CURL_OPTS+=(--resolve "${CURL_RESOLVE}")
fi

pass=0
fail=0

log() { printf '[smoke-critical] %s\n' "$*" >&2; }

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
  local phone="$1" code="$2" label="$3"
  split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/code" \
    -d "{\"phone\":\"${phone}\"}")"
  assert_http "${label} authPhoneSendCode" "200" "${HTTP_CODE}"
  assert_body_contains "${label} authPhoneSendCode OK" '"code"[[:space:]]*:[[:space:]]*"OK"' "${BODY}"

  split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/login" \
    -d "{\"phone\":\"${phone}\",\"code\":\"${code}\"}")"
  assert_http "${label} authPhoneLogin" "200" "${HTTP_CODE}"
  assert_body_contains "${label} accessToken" 'accessToken' "${BODY}"

  local token
  token=$(json_field "${BODY}" '.data.accessToken')
  [[ -n "${token}" ]] || { log "FAIL ${label}: no accessToken"; fail=$((fail + 1)); echo ""; return; }
  echo "${token}"
}

poll_ai_task_terminal() {
  local token="$1" task_id="$2" out_var="$3"
  local i=0 state="" body=""
  while [[ "${i}" -lt "${POLL_MAX}" ]]; do
    split_response "$(curl "${CURL_OPTS[@]}" -H "Authorization: Bearer ${token}" \
      "${BASE_URL}/v1/ai/tasks/${task_id}")"
    body="${BODY}"
    state=$(json_field "${body}" '.data.state')
    case "${state}" in
      succeeded|failed|rejected|appealed|cancelled)
        printf -v "${out_var}" '%s' "${body}"
        return 0
        ;;
    esac
    sleep "${POLL_INTERVAL_SEC}"
    i=$((i + 1))
  done
  log "FAIL poll ${task_id}: timeout (last state=${state})"
  fail=$((fail + 1))
  printf -v "${out_var}" '%s' "${body}"
  return 1
}

# ═══════════════════════════════════════════════════════════
log "══ Phase 0: Health ══"
split_response "$(curl "${CURL_OPTS[@]}" "${BASE_URL}/health")"
assert_http "health" "200" "${HTTP_CODE}"

# ═══════════════════════════════════════════════════════════
log "══ Phase 1: Login (P0/P1) ══"
ADMIN_TOKEN="$(auth_login "${ADMIN_PHONE}" "${ADMIN_CODE}" "admin")"
ADMIN_AUTH=("${CURL_OPTS[@]}" -H "Authorization: Bearer ${ADMIN_TOKEN}")

# ═══════════════════════════════════════════════════════════
log "══ Phase 2: Family (P1 subset) ══"
split_response "$(curl "${ADMIN_AUTH[@]}" -X POST "${BASE_URL}/v1/families" \
  -d '{"name":"T7.12冒烟家庭"}')"
assert_http "familyCreate" "200" "${HTTP_CODE}"
assert_body_contains "familyCreate familyId" 'familyId' "${BODY}"

FAMILY_ID=$(json_field "${BODY}" '.data.familyId')
[[ -n "${FAMILY_ID}" ]] || FAMILY_ID="fam_e2e_001"

split_response "$(curl "${ADMIN_AUTH[@]}" -X POST "${BASE_URL}/v1/families/${FAMILY_ID}/invitations")"
assert_http "familyCreateInvitation" "200" "${HTTP_CODE}"
assert_body_contains "familyCreateInvitation code" '"code"' "${BODY}"

INVITE_CODE=$(json_field "${BODY}" '.data.code')
[[ -n "${INVITE_CODE}" ]] || INVITE_CODE="888888"

MEMBER_TOKEN="$(auth_login "${MEMBER_PHONE}" "${MEMBER_CODE}" "member")"
MEMBER_AUTH=("${MEMBER_CURL_OPTS[@]}" -H "Authorization: Bearer ${MEMBER_TOKEN}")

split_response "$(curl "${MEMBER_AUTH[@]}" -X POST "${BASE_URL}/v1/invitations/${INVITE_CODE}/join" \
  -d '{"relation":"grandma","nickname":"外婆"}')"
assert_http "familyJoinByInvitation" "200" "${HTTP_CODE}"
assert_body_contains "familyJoinByInvitation role" '"role"' "${BODY}"

split_response "$(curl "${ADMIN_AUTH[@]}" "${BASE_URL}/v1/families/${FAMILY_ID}/members")"
assert_http "familyListMembers" "200" "${HTTP_CODE}"
assert_body_contains "familyListMembers items" 'items' "${BODY}"

split_response "$(curl "${ADMIN_AUTH[@]}" -X POST "${BASE_URL}/v1/families/${FAMILY_ID}/babies" \
  -d '{"name":"小测","birthday":"2024-06-01","gender":"unknown"}')"
assert_http "babyCreate" "200" "${HTTP_CODE}"
assert_body_contains "babyCreate babyId" 'babyId' "${BODY}"

BABY_ID=$(json_field "${BODY}" '.data.babyId')
[[ -n "${BABY_ID}" ]] || BABY_ID="bb_e2e_001"

# ═══════════════════════════════════════════════════════════
log "══ Phase 3: Publish mock (P0 subset) ══"
UPLOAD_INIT_BODY=$(cat <<EOF
{
  "purpose": "post-item",
  "familyId": "${FAMILY_ID}",
  "items": [{
    "clientRef": "smoke-ref-001",
    "kind": "photo",
    "mime": "image/jpeg",
    "size": 1024,
    "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  }]
}
EOF
)
split_response "$(curl "${ADMIN_AUTH[@]}" -X POST "${BASE_URL}/v1/uploads/init" -d "${UPLOAD_INIT_BODY}")"
assert_http "uploadInit post-item" "200" "${HTTP_CODE}"
assert_body_contains "uploadInit objectKey" 'objectKey' "${BODY}"

UPLOAD_URL=$(json_field "${BODY}" '.data.items[0].uploadUrl')
OBJECT_KEY=$(json_field "${BODY}" '.data.items[0].objectKey')
[[ -n "${OBJECT_KEY}" ]] || OBJECT_KEY="mock/cn/${FAMILY_ID}/photo_smoke_001.jpg"

if [[ -n "${UPLOAD_URL}" ]]; then
  split_response "$(curl -sS -w "\n%{http_code}" -X PUT "${UPLOAD_URL}" \
    -H "Content-Type: image/jpeg" --data-binary @/dev/null)"
  assert_http "mockOssPut" "200" "${HTTP_CODE}"
fi

split_response "$(curl "${ADMIN_AUTH[@]}" -X POST "${BASE_URL}/v1/uploads/complete" \
  -d '{"uploadId":"upl_smoke_001"}')"
assert_http "uploadComplete" "200" "${HTTP_CODE}"
assert_body_contains "uploadComplete completed" 'completed' "${BODY}"

POST_BODY=$(cat <<EOF
{
  "familyId": "${FAMILY_ID}",
  "babyId": "${BABY_ID}",
  "caption": "T7.12 关键路径冒烟发布",
  "media": [{
    "objectKey": "${OBJECT_KEY}",
    "kind": "photo"
  }]
}
EOF
)
split_response "$(curl "${ADMIN_AUTH[@]}" -X POST "${BASE_URL}/v1/posts" -d "${POST_BODY}")"
assert_http "postCreate" "200" "${HTTP_CODE}"
assert_body_contains "postCreate postId" 'postId' "${BODY}"
assert_body_contains "postCreate published" '"status"[[:space:]]*:[[:space:]]*"published"' "${BODY}"

POST_ID=$(json_field "${BODY}" '.data.postId')
[[ -n "${POST_ID}" ]] || POST_ID="post_smoke_001"

# ═══════════════════════════════════════════════════════════
log "══ Phase 4: AI mock (P3 subset) ══"
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" "${BASE_URL}/v1/ai/plays")"
assert_http "aiListPlays" "200" "${HTTP_CODE}"
assert_body_contains "aiListPlays ghibli_kid" 'ghibli_kid' "${BODY}"

split_response "$(curl "${ADMIN_AUTH[@]}" -X POST "${BASE_URL}/v1/uploads/init" \
  -d "{\"purpose\":\"ai-input\",\"familyId\":\"${FAMILY_ID}\",\"items\":[{\"clientRef\":\"ai-smoke-1\",\"kind\":\"photo\",\"mime\":\"image/heic\",\"size\":2048}]}")"
assert_http "uploadInit ai-input" "200" "${HTTP_CODE}"

AI_PAYLOAD=$(cat <<EOF
{"play":"ghibli_kid","inputObjectKey":"${INPUT_KEY}","familyId":"${FAMILY_ID}","params":{"aspectRatio":"1:1"}}
EOF
)
split_response "$(curl "${ADMIN_AUTH[@]}" -X POST "${BASE_URL}/v1/ai/tasks" -d "${AI_PAYLOAD}")"
CREATE_AI_BODY="${BODY}"
assert_http "aiCreateTask ghibli_kid" "200" "${HTTP_CODE}"
assert_body_contains "aiCreateTask taskId" 'taskId' "${CREATE_AI_BODY}"
assert_body_contains "aiCreateTask play" 'ghibli_kid' "${CREATE_AI_BODY}"

TASK_ID=$(json_field "${CREATE_AI_BODY}" '.data.taskId')
[[ -n "${TASK_ID}" ]] || TASK_ID="tsk_smoke_happy"

POLL_BODY=""
poll_ai_task_terminal "${ADMIN_TOKEN}" "${TASK_ID}" POLL_BODY || true
assert_body_contains "ai task succeeded" '"state"[[:space:]]*:[[:space:]]*"succeeded"' "${POLL_BODY}"
assert_body_contains "ai resultUrl" 'resultUrl' "${POLL_BODY}"
assert_body_contains "ai deepSynth" 'deepSynth' "${POLL_BODY}"

# ═══════════════════════════════════════════════════════════
log "══ Phase 5: Feed verify (P5 subset) ══"
split_response "$(curl "${MEMBER_CURL_OPTS[@]}" "${MEMBER_AUTH[@]}" \
  "${BASE_URL}/v1/feeds/family?familyId=${FAMILY_ID}&limit=20")"
assert_http "feedListFamily" "200" "${HTTP_CODE}"
assert_body_contains "feed contains post" "${POST_ID}" "${BODY}"
assert_body_contains "feed cacheTtlSeconds" '"cacheTtlSeconds"[[:space:]]*:[[:space:]]*60' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${MEMBER_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/posts/${POST_ID}/likes")"
assert_http "postLike" "200" "${HTTP_CODE}"
assert_body_contains "postLike postId" '"postId"' "${BODY}"

# ═══════════════════════════════════════════════════════════
log "────────────────────────────────────"
log "Results: ${pass} passed assertions, ${fail} failed"
if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi
log "T7.12 smoke-critical PASSED: login → family → publish(mock) → AI(mock) → feed (${pass} assertions)"
exit 0
