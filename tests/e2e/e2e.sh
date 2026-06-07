#!/usr/bin/env bash
# P1 E2E：登录 → 创建家庭 → 邀请家人 → 创建宝宝 → 注销
# 对齐 auth-family-svc · contracts/openapi operationId
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/e2e.env" ]] && source "${SCRIPT_DIR}/e2e.env"

BASE_URL="${BASE_URL:-http://localhost:18080}"
REGION="${E2E_REGION:-cn}"
APP_VERSION="${E2E_APP_VERSION:-1.0.0-staging}"
DEVICE_ID="${E2E_DEVICE_ID:-qa-device-iphone12-001}"
ADMIN_PHONE="${E2E_ADMIN_PHONE:-13800138001}"
ADMIN_CODE="${E2E_ADMIN_CODE:-123456}"
MEMBER_PHONE="${E2E_MEMBER_PHONE:-13800138002}"
MEMBER_CODE="${E2E_MEMBER_CODE:-123456}"
CURL_RESOLVE="${STAGING_RESOLVE:-}"

CURL_OPTS=(-sS -w "\n%{http_code}" -H "Content-Type: application/json" \
  -H "X-Region: ${REGION}" \
  -H "X-App-Version: ${APP_VERSION}" \
  -H "X-Device-Id: ${DEVICE_ID}")

if [[ -n "${CURL_RESOLVE}" ]]; then
  CURL_OPTS+=(--resolve "${CURL_RESOLVE}")
fi

pass=0
fail=0

log() { printf '[e2e] %s\n' "$*" >&2; }

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
  log "Step: POST /v1/auth/phone/code (${label})"
  split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/code" \
    -d "{\"phone\":\"${phone}\"}")"
  assert_http "${label} authPhoneSendCode" "200" "${HTTP_CODE}"

  log "Step: POST /v1/auth/phone/login (${label})"
  split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/login" \
    -d "{\"phone\":\"${phone}\",\"code\":\"${code}\"}")"
  assert_http "${label} authPhoneLogin" "200" "${HTTP_CODE}"
  assert_body_contains "${label} accessToken" 'accessToken' "${BODY}"

  local token
  token=$(json_field "${BODY}" '.data.accessToken')
  [[ -n "${token}" ]] || { log "FAIL ${label}: 无法解析 accessToken"; fail=$((fail + 1)); echo ""; return; }
  echo "${token}"
}

# ── Step 0: health ─────────────────────────────────────────
log "Step 0: GET /health @ ${BASE_URL}"
split_response "$(curl "${CURL_OPTS[@]}" "${BASE_URL}/health")"
assert_http "health" "200" "${HTTP_CODE}"

# ── Step 1-2: 管理员登录 ───────────────────────────────────
ADMIN_TOKEN="$(auth_login "${ADMIN_PHONE}" "${ADMIN_CODE}" "admin")"
ADMIN_AUTH=("${CURL_OPTS[@]}" -H "Authorization: Bearer ${ADMIN_TOKEN}")

# ── Step 3: 创建家庭 ───────────────────────────────────────
log "Step 3: POST /v1/families (familyCreate)"
split_response "$(curl "${ADMIN_AUTH[@]}" -X POST "${BASE_URL}/v1/families" \
  -d '{"name":"E2E测试家庭"}')"
assert_http "familyCreate" "200" "${HTTP_CODE}"
assert_body_contains "familyCreate familyId" 'familyId' "${BODY}"

FAMILY_ID=$(json_field "${BODY}" '.data.familyId')
[[ -n "${FAMILY_ID}" ]] || FAMILY_ID="fam_e2e_001"

# ── Step 4: 生成邀请码 ─────────────────────────────────────
log "Step 4: POST /v1/families/${FAMILY_ID}/invitations (familyCreateInvitation)"
split_response "$(curl "${ADMIN_AUTH[@]}" -X POST "${BASE_URL}/v1/families/${FAMILY_ID}/invitations")"
assert_http "familyCreateInvitation" "200" "${HTTP_CODE}"
assert_body_contains "familyCreateInvitation code" '"code"' "${BODY}"

INVITE_CODE=$(json_field "${BODY}" '.data.code')
[[ -n "${INVITE_CODE}" ]] || INVITE_CODE="888888"

# ── Step 5-6: 家庭成员登录并加入 ───────────────────────────
MEMBER_TOKEN="$(auth_login "${MEMBER_PHONE}" "${MEMBER_CODE}" "member")"
MEMBER_AUTH=("${CURL_OPTS[@]}" -H "Authorization: Bearer ${MEMBER_TOKEN}")

log "Step 7: POST /v1/invitations/${INVITE_CODE}/join (familyJoinByInvitation)"
split_response "$(curl "${MEMBER_AUTH[@]}" -X POST "${BASE_URL}/v1/invitations/${INVITE_CODE}/join" \
  -d '{"relation":"grandma","nickname":"外婆"}')"
assert_http "familyJoinByInvitation" "200" "${HTTP_CODE}"
assert_body_contains "familyJoinByInvitation role" '"role"' "${BODY}"

# ── Step 8: 验证成员列表 ───────────────────────────────────
log "Step 8: GET /v1/families/${FAMILY_ID}/members (familyListMembers)"
split_response "$(curl "${ADMIN_AUTH[@]}" "${BASE_URL}/v1/families/${FAMILY_ID}/members")"
assert_http "familyListMembers" "200" "${HTTP_CODE}"
assert_body_contains "familyListMembers items" 'items' "${BODY}"

# ── Step 9: 创建宝宝 ───────────────────────────────────────
log "Step 9: POST /v1/families/${FAMILY_ID}/babies (babyCreate)"
split_response "$(curl "${ADMIN_AUTH[@]}" -X POST "${BASE_URL}/v1/families/${FAMILY_ID}/babies" \
  -d '{"name":"小测","birthday":"2024-06-01","gender":"unknown"}')"
assert_http "babyCreate" "200" "${HTTP_CODE}"
assert_body_contains "babyCreate babyId" 'babyId' "${BODY}"

# ── Step 10: 注销账号 ──────────────────────────────────────
log "Step 10: DELETE /v1/account (accountDelete)"
split_response "$(curl "${ADMIN_AUTH[@]}" -X DELETE "${BASE_URL}/v1/account")"
assert_http "accountDelete" "200" "${HTTP_CODE}"
assert_body_contains "accountDelete scheduledAt" 'scheduledAt' "${BODY}"

# ── 汇总 ───────────────────────────────────────────────────
log "────────────────────────────────────"
log "Results: ${pass} passed assertions, ${fail} failed"
if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi
log "P1 E2E PASSED: login → family → invite → baby → delete account"
exit 0
