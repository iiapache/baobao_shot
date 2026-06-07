#!/usr/bin/env bash
# P6 备份/Widget/设置导出/注销 E2E（T6.15）：iCloud · 百度网盘 · 系统相册 bind/list/unbind/status；
# 失败重试上报；数据导出 zip 可解压；Widget 三尺寸+锁屏元数据；账号注销入口
# 对齐 auth-family-svc · contracts/openapi §backup · tests/mocks/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/e2e.env" ]] && source "${SCRIPT_DIR}/e2e.env"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/p6-backup.env" ]] && source "${SCRIPT_DIR}/p6-backup.env"

BASE_URL="${BASE_URL:-http://localhost:18080}"
REGION="${E2E_REGION:-cn}"
APP_VERSION="${E2E_APP_VERSION:-1.0.0-staging}"
DEVICE_ID="${E2E_DEVICE_ID:-qa-device-iphone12-001}"
ADMIN_PHONE="${E2E_ADMIN_PHONE:-13800138001}"
ADMIN_CODE="${E2E_ADMIN_CODE:-123456}"
BAIDU_EXPIRES="${P6_BAIDU_EXPIRES:-2026-07-01T00:00:00Z}"
EXPORT_ZIP_TMP="${P6_EXPORT_ZIP_TMP:-/tmp/baobao-p6-export-sample.zip}"

CURL_OPTS=(-sS -w "\n%{http_code}" -H "Content-Type: application/json" \
  -H "X-Region: ${REGION}" \
  -H "X-App-Version: ${APP_VERSION}" \
  -H "X-Device-Id: ${DEVICE_ID}")

pass=0
fail=0

log() { printf '[p6-e2e] %s\n' "$*" >&2; }

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
    log "PASS ${step} (no secret leak)"
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

json_build() {
  if command -v jq >/dev/null 2>&1; then
    jq -nc "$@"
  else
    echo "{}"
  fi
}

auth_login_verify() {
  split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/code" \
    -d "{\"phone\":\"${ADMIN_PHONE}\"}")"
  assert_http "authPhoneSendCode" "200" "${HTTP_CODE}"

  split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/login" \
    -d "{\"phone\":\"${ADMIN_PHONE}\",\"code\":\"${ADMIN_CODE}\"}")"
  assert_http "authPhoneLogin" "200" "${HTTP_CODE}"
  assert_body_contains "auth accessToken" 'accessToken' "${BODY}"
}

# ── 前置 ─────────────────────────────────────────────────────
log "Step 0: GET /health @ ${BASE_URL}"
split_response "$(curl "${CURL_OPTS[@]}" "${BASE_URL}/health")"
assert_http "health" "200" "${HTTP_CODE}"

auth_login_verify
ADMIN_TOKEN="mock_access_token_admin"
ADMIN_AUTH=(-H "Authorization: Bearer ${ADMIN_TOKEN}")

log "Step: backup unauthorized"
split_response "$(curl "${CURL_OPTS[@]}" "${BASE_URL}/v1/backup/providers")"
assert_http "backupList unauthorized" "401" "${HTTP_CODE}"

# ── 场景 A：三套备份 bind ────────────────────────────────────
log "── Scenario A: Bind iCloud / Baidu / Photos ──"

split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/backup/providers" \
  -d '{"kind":"icloud"}')"
assert_http "bindICloud" "200" "${HTTP_CODE}"
assert_body_contains "icloud kind" '"kind"[[:space:]]*:[[:space:]]*"icloud"' "${BODY}"
assert_body_contains "icloud status active" '"status"[[:space:]]*:[[:space:]]*"active"' "${BODY}"
ICLOUD_ID=$(json_field "${BODY}" '.data.id')
[[ -n "${ICLOUD_ID}" ]] || { log "FAIL bindICloud: no id"; fail=$((fail + 1)); ICLOUD_ID="bkp_icld_fallback"; }

BAIDU_BODY="$(json_build \
  --arg expires "${BAIDU_EXPIRES}" \
  '{kind:"baidu_pan", accessToken:"baidu-access-e2e", refreshToken:"baidu-refresh-e2e", expiresAt:$expires, providerAccountId:"baidu-user-e2e", metadata:{scope:"basic"}}')"
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/backup/providers" -d "${BAIDU_BODY}")"
assert_http "bindBaiduPan" "200" "${HTTP_CODE}"
assert_body_contains "baidu kind" '"kind"[[:space:]]*:[[:space:]]*"baidu_pan"' "${BODY}"
assert_body_contains "baidu providerAccountId" '"providerAccountId"[[:space:]]*:[[:space:]]*"baidu-user-e2e"' "${BODY}"
assert_body_not_contains "baidu no accessToken in response" '"accessToken"' "${BODY}"
BAIDU_ID=$(json_field "${BODY}" '.data.id')

split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/backup/providers" \
  -d '{"kind":"photos","metadata":{"platform":"ios"}}')"
assert_http "bindPhotos" "200" "${HTTP_CODE}"
assert_body_contains "photos kind" '"kind"[[:space:]]*:[[:space:]]*"photos"' "${BODY}"
PHOTOS_ID=$(json_field "${BODY}" '.data.id')

split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  "${BASE_URL}/v1/backup/providers")"
assert_http "backupList three providers" "200" "${HTTP_CODE}"
assert_body_contains "list icloud" '"kind"[[:space:]]*:[[:space:]]*"icloud"' "${BODY}"
assert_body_contains "list baidu_pan" '"kind"[[:space:]]*:[[:space:]]*"baidu_pan"' "${BODY}"
assert_body_contains "list photos" '"kind"[[:space:]]*:[[:space:]]*"photos"' "${BODY}"
assert_body_contains "list items array" '"items"' "${BODY}"

# upsert 同 kind 不新增条目
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/backup/providers" \
  -d '{"kind":"icloud","metadata":{"region":"cn"}}')"
assert_http "bindICloud upsert" "200" "${HTTP_CODE}"
assert_body_contains "icloud upsert same id" "${ICLOUD_ID}" "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  "${BASE_URL}/v1/backup/providers")"
LIST_COUNT=$(json_field "${BODY}" '.data.items | length')
if [[ "${LIST_COUNT}" == "3" ]]; then
  log "PASS list count remains 3 after upsert"
  pass=$((pass + 1))
else
  log "FAIL list count expected 3, got ${LIST_COUNT:-unknown}"
  fail=$((fail + 1))
fi

# ── 场景 B：校验失败路径 ─────────────────────────────────────
log "── Scenario B: Validation errors ──"
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/backup/providers" \
  -d '{"kind":"dropbox","accessToken":"x"}')"
assert_http "bindInvalidKind" "400" "${HTTP_CODE}"
assert_body_contains "invalid provider code" 'BACKUP_INVALID_PROVIDER' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/backup/providers" \
  -d '{"kind":"baidu_pan"}')"
assert_http "bindBaiduMissingToken" "400" "${HTTP_CODE}"
assert_body_contains "baidu token required" 'COMMON_BAD_PARAM' "${BODY}"

# ── 场景 C：unbind ───────────────────────────────────────────
log "── Scenario C: Unbind providers ──"
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X DELETE "${BASE_URL}/v1/backup/providers/${BAIDU_ID}")"
assert_http "unbindBaidu" "200" "${HTTP_CODE}"
assert_body_contains "unbind id" "${BAIDU_ID}" "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X DELETE "${BASE_URL}/v1/backup/providers/${BAIDU_ID}")"
assert_http "unbindBaidu again" "404" "${HTTP_CODE}"
assert_body_contains "unbind not found" 'COMMON_NOT_FOUND' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  "${BASE_URL}/v1/backup/providers")"
assert_http "list after unbind" "200" "${HTTP_CODE}"
if echo "${BODY}" | grep -q 'baidu_pan'; then
  log "FAIL list still contains baidu_pan after unbind"
  fail=$((fail + 1))
else
  log "PASS list excludes baidu_pan"
  pass=$((pass + 1))
fi
assert_body_contains "list still has icloud" '"kind"[[:space:]]*:[[:space:]]*"icloud"' "${BODY}"
assert_body_contains "list still has photos" '"kind"[[:space:]]*:[[:space:]]*"photos"' "${BODY}"

# 重新绑定百度（后续 status 场景需要三套齐全）
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/backup/providers" -d "${BAIDU_BODY}")"
assert_http "rebindBaiduPan" "200" "${HTTP_CODE}"
BAIDU_ID=$(json_field "${BODY}" '.data.id')

# ── 场景 D：status 空态 → 失败重试 → 成功清零 ───────────────
log "── Scenario D: Backup status retry flow ──"
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  "${BASE_URL}/v1/backup/status")"
assert_http "statusEmpty" "200" "${HTTP_CODE}"
assert_body_contains "status failureCount zero" '"failureCount"[[:space:]]*:[[:space:]]*0' "${BODY}"

ATTEMPT_1="2026-06-06T08:00:00Z"
FAIL_1="$(json_build --arg at "${ATTEMPT_1}" \
  '{success:false, attemptedAt:$at, errorCode:"BACKUP_NETWORK"}')"
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/backup/status" -d "${FAIL_1}")"
assert_http "reportFail1" "200" "${HTTP_CODE}"
assert_body_contains "fail1 failureCount" '"failureCount"[[:space:]]*:[[:space:]]*1' "${BODY}"
assert_body_contains "fail1 error code" 'BACKUP_NETWORK' "${BODY}"

ATTEMPT_2="2026-06-06T08:05:00Z"
FAIL_2="$(json_build --arg at "${ATTEMPT_2}" \
  '{success:false, attemptedAt:$at, errorCode:"BACKUP_QUOTA_EXCEEDED"}')"
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/backup/status" -d "${FAIL_2}")"
assert_http "reportFail2" "200" "${HTTP_CODE}"
assert_body_contains "fail2 failureCount" '"failureCount"[[:space:]]*:[[:space:]]*2' "${BODY}"

ATTEMPT_3="2026-06-06T08:10:00Z"
FAIL_3="$(json_build --arg at "${ATTEMPT_3}" \
  '{success:false, attemptedAt:$at, errorCode:"BACKUP_AUTH_REVOKED"}')"
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/backup/status" -d "${FAIL_3}")"
assert_http "reportFail3" "200" "${HTTP_CODE}"
assert_body_contains "fail3 failureCount" '"failureCount"[[:space:]]*:[[:space:]]*3' "${BODY}"
assert_body_contains "fail3 lastErrorCode" 'BACKUP_AUTH_REVOKED' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  "${BASE_URL}/v1/backup/status")"
assert_http "statusAfter3Fails" "200" "${HTTP_CODE}"
assert_body_contains "status GET failureCount 3" '"failureCount"[[:space:]]*:[[:space:]]*3' "${BODY}"

SUCCESS_AT="2026-06-06T09:00:00Z"
SUCCESS_BODY="$(json_build --arg at "${SUCCESS_AT}" '{success:true, attemptedAt:$at}')"
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/backup/status" -d "${SUCCESS_BODY}")"
assert_http "reportSuccess" "200" "${HTTP_CODE}"
assert_body_contains "success failureCount reset" '"failureCount"[[:space:]]*:[[:space:]]*0' "${BODY}"
assert_body_contains "success lastSuccessAt" '"lastSuccessAt"' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  "${BASE_URL}/v1/backup/status")"
assert_http "statusAfterSuccess" "200" "${HTTP_CODE}"
assert_body_contains "status cleared error" '"lastErrorCode"[[:space:]]*:[[:space:]]*null' "${BODY}"

# ── 场景 E：Widget 元数据（三尺寸 + 锁屏）────────────────────
log "── Scenario E: Widget kinds metadata ──"
split_response "$(curl "${CURL_OPTS[@]}" "${BASE_URL}/v1/e2e/backup/widget-kinds")"
assert_http "widgetKinds" "200" "${HTTP_CODE}"
assert_body_contains "widget small" 'BabyCameraWidgetSmall' "${BODY}"
assert_body_contains "widget medium" 'BabyCameraWidgetMedium' "${BODY}"
assert_body_contains "widget large" 'BabyCameraWidgetLarge' "${BODY}"
assert_body_contains "widget lock screen" 'BabyCameraWidgetLockScreen' "${BODY}"
assert_body_contains "widget systemSmall" 'systemSmall' "${BODY}"
assert_body_contains "widget accessoryCircular" 'accessoryCircular' "${BODY}"

# ── 场景 F：数据导出 API + zip 可解压 ────────────────────────
log "── Scenario F: Account export + sample zip ──"
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/account/export")"
assert_http "accountExport" "202" "${HTTP_CODE}"
assert_body_contains "export exportId" 'exportId' "${BODY}"
assert_body_contains "export status queued" '"status"[[:space:]]*:[[:space:]]*"queued"' "${BODY}"
EXPORT_ID=$(json_field "${BODY}" '.data.exportId')

split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/account/export")"
assert_http "accountExport idempotent" "202" "${HTTP_CODE}"
EXPORT_ID_2=$(json_field "${BODY}" '.data.exportId')
if [[ -n "${EXPORT_ID}" && "${EXPORT_ID}" == "${EXPORT_ID_2}" ]]; then
  log "PASS export idempotent same exportId"
  pass=$((pass + 1))
else
  log "FAIL export idempotent exportId mismatch: ${EXPORT_ID} vs ${EXPORT_ID_2}"
  fail=$((fail + 1))
fi

log "Step: GET /v1/e2e/backup/export-sample (zip integrity)"
HTTP_CODE=$(curl -sS -o "${EXPORT_ZIP_TMP}" -w "%{http_code}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${BASE_URL}/v1/e2e/backup/export-sample")
assert_http "exportSampleZip" "200" "${HTTP_CODE}"

if [[ -f "${EXPORT_ZIP_TMP}" && -s "${EXPORT_ZIP_TMP}" ]]; then
  log "PASS export zip file exists"
  pass=$((pass + 1))
else
  log "FAIL export zip missing or empty"
  fail=$((fail + 1))
fi

if command -v unzip >/dev/null 2>&1; then
  ZIP_ENTRIES=$(unzip -Z1 "${EXPORT_ZIP_TMP}" 2>/dev/null || true)
  if unzip -t "${EXPORT_ZIP_TMP}" >/dev/null 2>&1; then
    log "PASS export zip unzip -t"
    pass=$((pass + 1))
  else
    log "FAIL export zip unzip -t failed"
    fail=$((fail + 1))
  fi
  if echo "${ZIP_ENTRIES}" | grep -Fxq 'manifest.json'; then
    log "PASS export zip contains manifest.json"
    pass=$((pass + 1))
  else
    log "FAIL export zip missing manifest.json"
    fail=$((fail + 1))
  fi
  if echo "${ZIP_ENTRIES}" | grep -Fxq 'timeline.html'; then
    log "PASS export zip contains timeline.html"
    pass=$((pass + 1))
  else
    log "FAIL export zip missing timeline.html"
    fail=$((fail + 1))
  fi
  if echo "${ZIP_ENTRIES}" | grep -Fxq 'photos/photo_1.heic'; then
    log "PASS export zip contains photos/photo_1.heic"
    pass=$((pass + 1))
  else
    log "FAIL export zip missing photo entry"
    fail=$((fail + 1))
  fi
else
  log "SKIP unzip checks (unzip not installed)"
fi

# ── 场景 G：注销 / 登出入口 ──────────────────────────────────
log "── Scenario G: Logout + account deletion ──"
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/account/logout")"
assert_http "accountLogout" "200" "${HTTP_CODE}"
assert_body_contains "logout OK code" '"code"[[:space:]]*:[[:space:]]*"OK"' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X DELETE "${BASE_URL}/v1/account")"
assert_http "accountDelete" "200" "${HTTP_CODE}"
assert_body_contains "delete requestedAt" 'requestedAt' "${BODY}"
assert_body_contains "delete scheduledAt" 'scheduledAt' "${BODY}"
assert_body_contains "delete revokeBefore" 'revokeBefore' "${BODY}"

# ── 汇总 ─────────────────────────────────────────────────────
log "────────────────────────────────────"
log "Results: ${pass} passed assertions, ${fail} failed"
if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi
log "P6 Backup E2E PASSED: icloud/baidu/photos bind · unbind · status retry · widget kinds · export zip · logout/delete"
exit 0
