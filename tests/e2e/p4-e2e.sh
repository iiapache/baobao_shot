#!/usr/bin/env bash
# P4 积分/订阅/广告 E2E（T4.17）：充值 → AI hold/commit/release · 签到/激励/邀请 · 订阅权益 · grace/refund
# 对齐 credit-sub-ad-svc · contracts/openapi §8 · tests/mocks/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/e2e.env" ]] && source "${SCRIPT_DIR}/e2e.env"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/p4-credit.env" ]] && source "${SCRIPT_DIR}/p4-credit.env"

BASE_URL="${BASE_URL:-http://localhost:18080}"
REGION="${E2E_REGION:-cn}"
APP_VERSION="${E2E_APP_VERSION:-1.0.0-staging}"
DEVICE_ID="${E2E_DEVICE_ID:-qa-device-iphone12-001}"
ADMIN_PHONE="${E2E_ADMIN_PHONE:-13800138001}"
ADMIN_CODE="${E2E_ADMIN_CODE:-123456}"
MEMBER_PHONE="${E2E_MEMBER_PHONE:-13800138002}"
MEMBER_CODE="${E2E_MEMBER_CODE:-123456}"
FAMILY_ID="${P4_FAMILY_ID:-fam_e2e_001}"
INPUT_KEY="${P4_INPUT_OBJECT_KEY:-ai-tmp/usr_e2e_admin/e2e-input.heic}"
IAP_TX_CREDITS="${P4_IAP_TX_CREDITS:-2000000123456789}"
IAP_PRODUCT_CREDITS="${P4_IAP_PRODUCT_CREDITS:-com.baobao.credits.100}"
IAP_TX_SUB="${P4_IAP_TX_SUB:-2000000987654321}"
IAP_PRODUCT_SUB="${P4_IAP_PRODUCT_SUB:-com.baobao.sub.monthly}"
PANGLE_SECRET="${P4_PANGLE_SECRET:-mock-pangle-secret}"

CURL_OPTS=(-sS -w "\n%{http_code}" -H "Content-Type: application/json" \
  -H "X-Region: ${REGION}" \
  -H "X-App-Version: ${APP_VERSION}" \
  -H "X-Device-Id: ${DEVICE_ID}")

pass=0
fail=0

log() { printf '[p4-e2e] %s\n' "$*" >&2; }

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

assert_json_eq() {
  local step="$1" jq_path="$2" expected="$3" body="$4"
  local actual
  actual=$(json_field "${body}" "${jq_path}")
  if [[ "${actual}" == "${expected}" ]]; then
    log "PASS ${step} (${jq_path}=${actual})"
    pass=$((pass + 1))
  else
    log "FAIL ${step} ${jq_path} expected '${expected}', got '${actual}'"
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

pangle_sign() {
  local trans_id="$1" user_id="$2"
  printf '%s:%s' "${trans_id}" "${user_id}" | openssl dgst -sha256 -hmac "${PANGLE_SECRET}" | awk '{print $2}'
}

auth_login() {
  local phone="$1" code="$2" label="$3"
  split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/code" \
    -d "{\"phone\":\"${phone}\"}")"
  assert_http "${label} authPhoneSendCode" "200" "${HTTP_CODE}"

  split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/login" \
    -d "{\"phone\":\"${phone}\",\"code\":\"${code}\"}")"
  assert_http "${label} authPhoneLogin" "200" "${HTTP_CODE}"
  local token
  token=$(json_field "${BODY}" '.data.accessToken')
  [[ -n "${token}" ]] || { log "FAIL ${label}: no accessToken"; fail=$((fail + 1)); echo ""; return; }
  echo "${token}"
}

poll_task_terminal() {
  local token="$1" task_id="$2" want_state="$3"
  local i=0 body="" state=""
  while [[ "${i}" -lt 8 ]]; do
    split_response "$(curl "${CURL_OPTS[@]}" -H "Authorization: Bearer ${token}" \
      "${BASE_URL}/v1/ai/tasks/${task_id}")"
    assert_http "aiGetTask ${task_id} poll $((i + 1))" "200" "${HTTP_CODE}"
    state=$(json_field "${BODY}" '.data.state')
    body="${BODY}"
    [[ "${state}" == "${want_state}" ]] && { echo "${body}"; return 0; }
    sleep 0.3
    i=$((i + 1))
  done
  log "FAIL poll ${task_id}: want ${want_state}, last=${state}"
  fail=$((fail + 1))
  echo "${body}"
  return 1
}

# ── 前置 ─────────────────────────────────────────────────────
log "Step 0: GET /health @ ${BASE_URL}"
split_response "$(curl "${CURL_OPTS[@]}" "${BASE_URL}/health")"
assert_http "health" "200" "${HTTP_CODE}"

TOKEN="$(auth_login "${ADMIN_PHONE}" "${ADMIN_CODE}" "admin")"
AUTH=(-H "Authorization: Bearer ${TOKEN}")

# ── 场景 A：余额 / 费率 / 商品目录 ───────────────────────────
log "── Scenario A: Balance & Catalog ──"
split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" "${BASE_URL}/v1/credits/balance")"
assert_http "creditsGetBalance" "200" "${HTTP_CODE}"
assert_body_contains "balance field" '"balance"' "${BODY}"
BAL_BEFORE=$(json_field "${BODY}" '.data.balance')
log "initial balance=${BAL_BEFORE}"

split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" "${BASE_URL}/v1/credits/rates")"
assert_http "creditsGetRates" "200" "${HTTP_CODE}"
assert_body_contains "rates ghibli_kid" 'ghibli_kid' "${BODY}"
assert_body_contains "rates rechargePacks" 'rechargePacks' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" "${BASE_URL}/v1/subscriptions/products")"
assert_http "subscriptionsListProducts" "200" "${HTTP_CODE}"
assert_body_contains "sub monthly sku" 'com.baobao.sub.monthly' "${BODY}"

# ── 场景 B：IAP 充值 + 幂等 ───────────────────────────────────
log "── Scenario B: IAP Recharge + Duplicate ──"
IAP_BODY=$(cat <<EOF
{"transactionId":"${IAP_TX_CREDITS}","signedTransaction":"mock:${IAP_TX_CREDITS}:${IAP_PRODUCT_CREDITS}","productId":"${IAP_PRODUCT_CREDITS}"}
EOF
)
split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" -X POST "${BASE_URL}/v1/credits/iap-verify" -d "${IAP_BODY}")"
assert_http "creditsIapVerify" "200" "${HTTP_CODE}"
assert_body_contains "iap grantedCredits" '"grantedCredits"' "${BODY}"
GRANTED=$(json_field "${BODY}" '.data.grantedCredits')
[[ "${GRANTED}" == "100" || "${GRANTED}" == "100.0" ]] && { log "PASS iap granted 100"; pass=$((pass + 1)); } || { log "FAIL iap granted=${GRANTED}"; fail=$((fail + 1)); }

split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" -X POST "${BASE_URL}/v1/credits/iap-verify" -d "${IAP_BODY}")"
assert_http "creditsIapVerify duplicate" "200" "${HTTP_CODE}"
assert_body_contains "iap duplicate flag" '"duplicate"[[:space:]]*:[[:space:]]*true' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" "${BASE_URL}/v1/credits/balance")"
assert_http "balance after iap" "200" "${HTTP_CODE}"

# ── 场景 C：AI hold → commit（happy）──────────────────────────
log "── Scenario C: AI Hold → Commit (happy) ──"
split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" -X POST "${BASE_URL}/v1/ai/tasks" \
  -d "{\"play\":\"ghibli_kid\",\"inputObjectKey\":\"${INPUT_KEY}\",\"familyId\":\"${FAMILY_ID}\",\"params\":{\"aspectRatio\":\"1:1\"}}")"
assert_http "aiCreateTask happy" "200" "${HTTP_CODE}"
assert_body_contains "happy credit_held" '"state"[[:space:]]*:[[:space:]]*"credit_held"' "${BODY}"
TASK_HAPPY=$(json_field "${BODY}" '.data.taskId')
BAL_HELD=$(json_field "${BODY}" '.data.balanceAfter')

POLL_HAPPY="$(poll_task_terminal "${TOKEN}" "${TASK_HAPPY}" "succeeded" || true)"
assert_body_contains "happy succeeded" '"state"[[:space:]]*:[[:space:]]*"succeeded"' "${POLL_HAPPY}"
BAL_COMMIT=$(json_field "${POLL_HAPPY}" '.data.balanceAfter')
log "balance held=${BAL_HELD} commit=${BAL_COMMIT}"

# ── 场景 D：AI hold → release（model_failed 退还）──────────────
log "── Scenario D: AI Hold → Release (model_failed) ──"
split_response "$(curl "${CURL_OPTS[@]}" -H "X-E2E-Scenario: model_failed" "${AUTH[@]}" \
  -X POST "${BASE_URL}/v1/ai/tasks" \
  -d "{\"play\":\"ghibli_kid\",\"inputObjectKey\":\"${INPUT_KEY}\",\"familyId\":\"${FAMILY_ID}\",\"params\":{\"aspectRatio\":\"1:1\"}}")"
assert_http "aiCreateTask model_failed" "200" "${HTTP_CODE}"
TASK_FAIL=$(json_field "${BODY}" '.data.taskId')
BAL_BEFORE_FAIL=$(json_field "${BODY}" '.data.balanceAfter')

POLL_FAIL="$(poll_task_terminal "${TOKEN}" "${TASK_FAIL}" "failed" || true)"
assert_body_contains "failed state" '"state"[[:space:]]*:[[:space:]]*"failed"' "${POLL_FAIL}"
assert_body_contains "refund hint" '退还积分' "${POLL_FAIL}"
BAL_AFTER_FAIL=$(json_field "${POLL_FAIL}" '.data.balanceAfter')
log "balance before_fail=${BAL_BEFORE_FAIL} after_refund=${BAL_AFTER_FAIL}"

# ── 场景 E：负余额边界 ───────────────────────────────────────
log "── Scenario E: Negative Balance Boundary ──"
split_response "$(curl "${CURL_OPTS[@]}" -H "X-E2E-Scenario: insufficient_balance" "${AUTH[@]}" \
  -X POST "${BASE_URL}/v1/ai/tasks" \
  -d "{\"play\":\"ghibli_kid\",\"inputObjectKey\":\"${INPUT_KEY}\",\"familyId\":\"${FAMILY_ID}\",\"params\":{\"aspectRatio\":\"1:1\"}}")"
assert_http "aiCreateTask negative" "200" "${HTTP_CODE}"
NEG_BAL=$(json_field "${BODY}" '.data.balanceAfter')
if [[ -n "${NEG_BAL}" ]] && [[ "${NEG_BAL}" =~ ^- ]]; then
  log "PASS negative balanceAfter (${NEG_BAL})"
  pass=$((pass + 1))
else
  log "FAIL negative balanceAfter expected < 0, got ${NEG_BAL}"
  fail=$((fail + 1))
fi

# ── 场景 F：签到 + 重复 ───────────────────────────────────────
log "── Scenario F: Sign-in + Duplicate ──"
split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" -X POST "${BASE_URL}/v1/credits/sign-in")"
assert_http "creditsSignIn" "200" "${HTTP_CODE}"
assert_body_contains "sign-in streak" '"streak"' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" -X POST "${BASE_URL}/v1/credits/sign-in")"
assert_http "creditsSignIn duplicate" "409" "${HTTP_CODE}"
assert_body_contains "sign-in done code" 'CREDIT_SIGN_IN_DONE' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" "${BASE_URL}/v1/credits/balance")"
assert_http "balance signInAvailable false" "200" "${HTTP_CODE}"
assert_body_contains "signInAvailable false" '"signInAvailable"[[:space:]]*:[[:space:]]*false' "${BODY}"

# ── 场景 G：激励广告（端侧 + 联盟回调）──────────────────────
log "── Scenario G: Ad Reward (client + pangle callback) ──"
TS_MS=$(($(date +%s) * 1000))
split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" \
  -H "X-Nonce: nonce-p4-e2e-001" -H "X-Timestamp: ${TS_MS}" \
  -X POST "${BASE_URL}/v1/credits/ad-reward" \
  -d '{"network":"pangle","placementId":"slot_e2e","transId":"p4-client-ad-001","idfv":"IDFV-P4-E2E"}')"
assert_http "creditsAdReward client" "200" "${HTTP_CODE}"
assert_body_contains "ad grantedCredits" '"grantedCredits"' "${BODY}"

PANGLE_TRANS="p4-pangle-cb-001"
PANGLE_SIG="$(pangle_sign "${PANGLE_TRANS}" "usr_e2e_admin")"
PANGLE_BODY=$(cat <<EOF
{"user_id":"usr_e2e_admin","trans_id":"${PANGLE_TRANS}","sign":"${PANGLE_SIG}","extra":"{}"}
EOF
)
split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/credits/ad-reward/pangle/callback" \
  -d "${PANGLE_BODY}")"
assert_http "pangle callback" "200" "${HTTP_CODE}"

PANGLE_FORGED_BODY='{"user_id":"usr_e2e_admin","trans_id":"p4-pangle-forged","sign":"forged","extra":"{}"}'
split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/credits/ad-reward/pangle/callback" \
  -d "${PANGLE_FORGED_BODY}")"
assert_http "pangle forged sig" "403" "${HTTP_CODE}"
assert_body_contains "signature invalid" 'CREDIT_AD_SIGNATURE_INVALID' "${BODY}"

# ── 场景 H：邀请赠分（成员加入 → 管理员 +50）────────────────
log "── Scenario H: Invite Grant ──"
MEMBER_TOKEN="$(auth_login "${MEMBER_PHONE}" "${MEMBER_CODE}" "member")"
MEMBER_AUTH=(-H "Authorization: Bearer ${MEMBER_TOKEN}")

split_response "$(curl "${CURL_OPTS[@]}" "${MEMBER_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/invitations/888888/join" \
  -d '{"relation":"grandma","nickname":"外婆"}')"
assert_http "familyJoinByInvitation" "200" "${HTTP_CODE}"

split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" "${BASE_URL}/v1/credits/transactions?limit=20")"
assert_http "creditsListTransactions" "200" "${HTTP_CODE}"
assert_body_contains "invite ledger refKind" 'invite' "${BODY}"

# ── 场景 I：订阅购买 → 权益 → 退订 ───────────────────────────
log "── Scenario I: Subscription Purchase → Entitlements → Refund ──"
split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" "${BASE_URL}/v1/subscriptions/me")"
assert_http "subscriptionsGetMe before" "200" "${HTTP_CODE}"

SUB_BODY=$(cat <<EOF
{"transactionId":"${IAP_TX_SUB}","signedTransaction":"mock:${IAP_TX_SUB}:${IAP_PRODUCT_SUB}:orig_e2e_sub","productId":"${IAP_PRODUCT_SUB}"}
EOF
)
split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" -X POST "${BASE_URL}/v1/subscriptions/iap-verify" -d "${SUB_BODY}")"
assert_http "subscriptionsIapVerify" "200" "${HTTP_CODE}"
assert_body_contains "sub active" '"state"[[:space:]]*:[[:space:]]*"active"' "${BODY}"
assert_body_contains "removeAds true" '"removeAds"[[:space:]]*:[[:space:]]*true' "${BODY}"
assert_body_contains "brandWatermarkRemovable" 'brandWatermarkRemovable' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" "${BASE_URL}/v1/subscriptions/me")"
assert_http "subscriptionsGetMe active" "200" "${HTTP_CODE}"
assert_body_contains "me active true" '"active"[[:space:]]*:[[:space:]]*true' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" -X POST "${BASE_URL}/v1/e2e/subscriptions/event" \
  -d '{"event":"refund"}')"
assert_http "e2e sub refund event" "200" "${HTTP_CODE}"
assert_body_contains "refund state" '"state"[[:space:]]*:[[:space:]]*"refunded"' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" "${BASE_URL}/v1/subscriptions/me")"
assert_http "subscriptionsGetMe refunded" "200" "${HTTP_CODE}"
assert_body_contains "removeAds false after refund" '"removeAds"[[:space:]]*:[[:space:]]*false' "${BODY}"

# ── 场景 J：续订 grace（权益保留）────────────────────────────
log "── Scenario J: Renewal Grace Period ──"
SUB_BODY_GRACE=$(cat <<EOF
{"transactionId":"2000000987654322","signedTransaction":"mock:2000000987654322:${IAP_PRODUCT_SUB}:orig_e2e_grace","productId":"${IAP_PRODUCT_SUB}"}
EOF
)
split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" -X POST "${BASE_URL}/v1/subscriptions/iap-verify" -d "${SUB_BODY_GRACE}")"
assert_http "re-subscribe for grace" "200" "${HTTP_CODE}"
assert_body_contains "grace sub active" '"state"[[:space:]]*:[[:space:]]*"active"' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${AUTH[@]}" -X POST "${BASE_URL}/v1/e2e/subscriptions/event" \
  -d '{"event":"grace"}')"
assert_http "e2e sub grace event" "200" "${HTTP_CODE}"
assert_body_contains "grace state" '"state"[[:space:]]*:[[:space:]]*"grace"' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" -H "X-E2E-Scenario: sub_grace" "${AUTH[@]}" \
  "${BASE_URL}/v1/subscriptions/me")"
assert_http "subscriptionsGetMe grace header" "200" "${HTTP_CODE}"
assert_body_contains "grace active entitlements" '"state"[[:space:]]*:[[:space:]]*"grace"' "${BODY}"
assert_body_contains "grace removeAds still true" '"removeAds"[[:space:]]*:[[:space:]]*true' "${BODY}"

# ── 汇总 ─────────────────────────────────────────────────────
log "────────────────────────────────────"
log "Results: ${pass} passed assertions, ${fail} failed"
if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi
log "P4 Credit E2E PASSED: iap · ai hold/commit/release · sign-in · ad · invite · sub · grace/refund · negative balance"
exit 0
