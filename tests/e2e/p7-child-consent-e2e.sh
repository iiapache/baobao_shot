#!/usr/bin/env bash
# P7 E2E：儿童信息监护人同意 — 未同意受限 / 版本校验 / 同意后放行
# 对齐 auth-family-svc T7.3 · compliance/policies/child-data-consent-v1.md
#
# 本地运行示例（memory 后端）：
#   MOCK_SMS_FIXED_CODE=123456 HTTP_PORT=18081 go run ./cmd/server  # auth-family-svc 目录
#   BASE_URL=http://localhost:18081 ./tests/e2e/p7-child-consent-e2e.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/e2e.env" ]] && source "${SCRIPT_DIR}/e2e.env"

BASE_URL="${BASE_URL:-http://localhost:18080}"
REGION="${E2E_REGION:-cn}"
APP_VERSION="${E2E_APP_VERSION:-1.0.0-staging}"
DEVICE_ID="${E2E_DEVICE_ID:-qa-device-p7-consent-001}"
PHONE="${E2E_CONSENT_PHONE:-13800138091}"
CODE="${E2E_CONSENT_CODE:-123456}"
CONSENT_VERSION="${E2E_CONSENT_VERSION:-child_consent_v1}"
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

log() { printf '[p7-consent-e2e] %s\n' "$*" >&2; }

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

assert_body_not_contains() {
  local step="$1" needle="$2" body="$3"
  if echo "${body}" | grep -qE "${needle}"; then
    log "FAIL ${step} body should not contain '${needle}'"
    fail=$((fail + 1))
  else
    log "PASS ${step} (body absent)"
    pass=$((pass + 1))
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

# 避免 bash 花括号展开（含逗号的 JSON 勿用 -d "{...}" 双引号形式）
json_phone_code() { printf '{"phone":"%s"}' "$1"; }
json_phone_login() { printf '{"phone":"%s","code":"%s"}' "$1" "$2"; }
json_consent_submit() { printf '{"version":"%s","accepted":%s}' "$1" "$2"; }

# ── Step 0: health ─────────────────────────────────────────
log "Step 0: GET /health"
split_response "$(curl "${CURL_OPTS[@]}" "${BASE_URL}/health")"
assert_http "health" "200" "${HTTP_CODE}"

# ── Step 1-2: 登录 ─────────────────────────────────────────
log "Step 1: POST /v1/auth/phone/code"
split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/code" \
  -d "$(json_phone_code "${PHONE}")")"
assert_http "authPhoneSendCode" "200" "${HTTP_CODE}"

log "Step 2: POST /v1/auth/phone/login"
split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/login" \
  -d "$(json_phone_login "${PHONE}" "${CODE}")")"
assert_http "authPhoneLogin" "200" "${HTTP_CODE}"
assert_body_contains "login accessToken" 'accessToken' "${BODY}"

TOKEN=$(json_field "${BODY}" '.data.accessToken')
[[ -n "${TOKEN}" ]] || { log "FAIL cannot parse accessToken"; fail=$((fail + 1)); }
AUTH=("${CURL_OPTS[@]}" -H "Authorization: Bearer ${TOKEN}")

# ── Step 3: 未同意时 GET /me ───────────────────────────────
log "Step 3: GET /v1/account/me (before consent)"
split_response "$(curl "${AUTH[@]}" "${BASE_URL}/v1/account/me")"
assert_http "accountGetMe" "200" "${HTTP_CODE}"
assert_body_contains "me childData false" '"childData":\s*false' "${BODY}"

# ── Step 4: 同意状态查询（需重新同意）──────────────────────
log "Step 4: GET /v1/account/consents/child-data"
split_response "$(curl "${AUTH[@]}" "${BASE_URL}/v1/account/consents/child-data")"
assert_http "accountGetChildConsent" "200" "${HTTP_CODE}"
assert_body_contains "consent currentVersion" "\"currentVersion\":\\s*\"${CONSENT_VERSION}\"" "${BODY}"
assert_body_contains "consent requiresConsent true" '"requiresConsent":\s*true' "${BODY}"
assert_body_contains "consent agreed false" '"agreed":\s*false' "${BODY}"

# ── Step 5: 未同意创建家庭被拒 ─────────────────────────────
log "Step 5: POST /v1/families without consent"
split_response "$(curl "${AUTH[@]}" -X POST "${BASE_URL}/v1/families" \
  -d '{"name":"P7同意测试家庭"}')"
assert_http "familyCreateBlocked" "422" "${HTTP_CODE}"
assert_body_contains "familyCreate ACCOUNT_CONSENT_REQUIRED" 'ACCOUNT_CONSENT_REQUIRED' "${BODY}"

# ── Step 6: 错误版本提交被拒 ───────────────────────────────
log "Step 6: POST consent with stale version"
split_response "$(curl "${AUTH[@]}" -X POST "${BASE_URL}/v1/account/consents/child-data" \
  -d '{"version":"child_consent_v0","accepted":true}')"
assert_http "submitStaleVersion" "422" "${HTTP_CODE}"
assert_body_contains "stale version error" 'COMMON_BAD_PARAM' "${BODY}"

# ── Step 7: 未勾选同意被拒 ───────────────────────────────────
log "Step 7: POST consent rejected=false"
split_response "$(curl "${AUTH[@]}" -X POST "${BASE_URL}/v1/account/consents/child-data" \
  -d "$(json_consent_submit "${CONSENT_VERSION}" false)")"
assert_http "submitNotAccepted" "422" "${HTTP_CODE}"

# ── Step 8: 提交当前版本同意 ───────────────────────────────
log "Step 8: POST consent accepted=true"
split_response "$(curl "${AUTH[@]}" -X POST "${BASE_URL}/v1/account/consents/child-data" \
  -d "$(json_consent_submit "${CONSENT_VERSION}" true)")"
assert_http "submitConsent" "200" "${HTTP_CODE}"
assert_body_contains "submitConsent version" "\"version\":\\s*\"${CONSENT_VERSION}\"" "${BODY}"
assert_body_contains "submitConsent agreedAt" 'agreedAt' "${BODY}"

# ── Step 9: 同意后 GET /me ─────────────────────────────────
log "Step 9: GET /v1/account/me (after consent)"
split_response "$(curl "${AUTH[@]}" "${BASE_URL}/v1/account/me")"
assert_http "accountGetMeAfterConsent" "200" "${HTTP_CODE}"
assert_body_contains "me childData true" '"childData":\s*true' "${BODY}"

# ── Step 10: 同意后状态查询 ──────────────────────────────────
log "Step 10: GET consent status after agree"
split_response "$(curl "${AUTH[@]}" "${BASE_URL}/v1/account/consents/child-data")"
assert_http "accountGetChildConsentAfter" "200" "${HTTP_CODE}"
assert_body_contains "consent agreed true" '"agreed":\s*true' "${BODY}"
assert_body_contains "consent requiresConsent false" '"requiresConsent":\s*false' "${BODY}"
assert_body_contains "consent agreedVersion" "\"agreedVersion\":\\s*\"${CONSENT_VERSION}\"" "${BODY}"

# ── Step 11: 创建家庭放行 ───────────────────────────────────
log "Step 11: POST /v1/families after consent"
split_response "$(curl "${AUTH[@]}" -X POST "${BASE_URL}/v1/families" \
  -d '{"name":"P7同意测试家庭"}')"
assert_http "familyCreateAllowed" "200" "${HTTP_CODE}"
assert_body_contains "familyCreate familyId" 'familyId' "${BODY}"

FAMILY_ID=$(json_field "${BODY}" '.data.familyId')
[[ -n "${FAMILY_ID}" ]] || FAMILY_ID="fam_p7_consent"

# ── Step 12: 创建宝宝放行 ───────────────────────────────────
log "Step 12: POST /v1/families/${FAMILY_ID}/babies"
split_response "$(curl "${AUTH[@]}" -X POST "${BASE_URL}/v1/families/${FAMILY_ID}/babies" \
  -d '{"name":"小合规","birthday":"2024-06-01","gender":"unknown"}')"
assert_http "babyCreateAllowed" "200" "${HTTP_CODE}"
assert_body_contains "babyCreate babyId" 'babyId' "${BODY}"

# ── 汇总 ───────────────────────────────────────────────────
log "────────────────────────────────────"
log "Results: ${pass} passed assertions, ${fail} failed"
if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi
log "P7 child consent e2e passed (${pass} assertions)"
