#!/usr/bin/env bash
# P0 冒烟：登录 → 拍照(mock) → 发布(mock)
# 对齐 contracts/openapi：authPhoneSendCode, authPhoneLogin, uploadInit, uploadComplete, postCreate
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/smoke.env" ]] && source "${SCRIPT_DIR}/smoke.env"

BASE_URL="${BASE_URL:-http://localhost:18080}"
REGION="${SMOKE_REGION:-cn}"
APP_VERSION="${SMOKE_APP_VERSION:-1.0.0-staging}"
DEVICE_ID="${SMOKE_DEVICE_ID:-qa-device-iphone12-001}"
PHONE="${SMOKE_PHONE:-13800138001}"
CODE="${SMOKE_CODE:-123456}"
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

log() { printf '[smoke] %s\n' "$*"; }
die() { log "FAIL: $*"; exit 1; }

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
  # last line = http code, rest = body
  HTTP_CODE=$(echo "$1" | tail -n1)
  BODY=$(echo "$1" | sed '$d')
}

# ── Step 0: health ─────────────────────────────────────────
log "Step 0: GET /health @ ${BASE_URL}"
split_response "$(curl "${CURL_OPTS[@]}" "${BASE_URL}/health")"
assert_http "health" "200" "${HTTP_CODE}"

# ── Step 1: 发送验证码 ─────────────────────────────────────
log "Step 1: POST /v1/auth/phone/code (authPhoneSendCode)"
split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/code" \
  -d "{\"phone\":\"${PHONE}\"}")"
assert_http "authPhoneSendCode" "200" "${HTTP_CODE}"
assert_body_contains "authPhoneSendCode code=OK" '"code"[[:space:]]*:[[:space:]]*"OK"' "${BODY}"

# ── Step 2: 登录 ───────────────────────────────────────────
log "Step 2: POST /v1/auth/phone/login (authPhoneLogin)"
split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/login" \
  -d "{\"phone\":\"${PHONE}\",\"code\":\"${CODE}\"}")"
assert_http "authPhoneLogin" "200" "${HTTP_CODE}"
assert_body_contains "authPhoneLogin accessToken" 'accessToken' "${BODY}"

ACCESS_TOKEN=""
if command -v jq >/dev/null 2>&1; then
  ACCESS_TOKEN=$(echo "${BODY}" | jq -r '.data.accessToken // empty')
else
  ACCESS_TOKEN=$(echo "${BODY}" | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p' | head -1)
fi
[[ -n "${ACCESS_TOKEN}" ]] || die "无法解析 accessToken"

AUTH_OPTS=("${CURL_OPTS[@]}" -H "Authorization: Bearer ${ACCESS_TOKEN}")

# ── Step 3: 拍照 mock — 申请上传凭据 ───────────────────────
log "Step 3: POST /v1/uploads/init (uploadInit · post-item)"
UPLOAD_INIT_BODY='{
  "purpose": "post-item",
  "familyId": "fam_smoke_001",
  "items": [{
    "clientRef": "photo-ref-001",
    "kind": "photo",
    "mime": "image/jpeg",
    "size": 1024,
    "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  }]
}'
split_response "$(curl "${AUTH_OPTS[@]}" -X POST "${BASE_URL}/v1/uploads/init" -d "${UPLOAD_INIT_BODY}")"
assert_http "uploadInit" "200" "${HTTP_CODE}"
assert_body_contains "uploadInit objectKey" 'objectKey' "${BODY}"

UPLOAD_URL=""
if command -v jq >/dev/null 2>&1; then
  UPLOAD_URL=$(echo "${BODY}" | jq -r '.data.items[0].uploadUrl // empty')
else
  UPLOAD_URL=$(echo "${BODY}" | sed -n 's/.*"uploadUrl":"\([^"]*\)".*/\1/p' | head -1)
fi

# ── Step 4: 拍照 mock — 直传 OSS（mock-oss）────────────────
if [[ -n "${UPLOAD_URL}" ]]; then
  log "Step 4: PUT mock OSS (${UPLOAD_URL})"
  split_response "$(curl -sS -w "\n%{http_code}" -X PUT "${UPLOAD_URL}" \
    -H "Content-Type: image/jpeg" \
    --data-binary @/dev/null)"
  assert_http "mockOssPut" "200" "${HTTP_CODE}"
else
  log "SKIP Step 4: 无 uploadUrl（staging 模式可能由客户端跳过）"
fi

# ── Step 5: 完成上传 ───────────────────────────────────────
log "Step 5: POST /v1/uploads/complete (uploadComplete)"
split_response "$(curl "${AUTH_OPTS[@]}" -X POST "${BASE_URL}/v1/uploads/complete" \
  -d '{"uploadId":"upl_smoke_001"}')"
assert_http "uploadComplete" "200" "${HTTP_CODE}"
assert_body_contains "uploadComplete status" 'completed' "${BODY}"

# ── Step 6: 发布 mock ──────────────────────────────────────
log "Step 6: POST /v1/posts (postCreate)"
POST_BODY='{
  "familyId": "fam_smoke_001",
  "babyId": "bb_smoke_001",
  "caption": "P0 冒烟发布（mock）",
  "media": [{
    "objectKey": "mock/cn/fam_smoke_001/photo_smoke_001.jpg",
    "kind": "photo"
  }]
}'
split_response "$(curl "${AUTH_OPTS[@]}" -X POST "${BASE_URL}/v1/posts" -d "${POST_BODY}")"
assert_http "postCreate" "200" "${HTTP_CODE}"
assert_body_contains "postCreate postId" 'postId' "${BODY}"

# ── 汇总 ───────────────────────────────────────────────────
log "────────────────────────────────────"
log "Results: ${pass} passed assertions, ${fail} failed"
if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi
log "P0 smoke PASSED: login → photo(mock) → publish(mock)"
exit 0
