#!/usr/bin/env bash
# P5 家庭圈/分享/文案/通知 E2E（T5.20）：发布→推送→浏览→点赞评论→撤回；微信/系统分享；智能文案；UGC 拒绝+申诉
# 对齐 feed-svc · caption-svc · notification-svc · contracts/openapi §7/§9/§10 · tests/mocks/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/e2e.env" ]] && source "${SCRIPT_DIR}/e2e.env"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/p5-feed.env" ]] && source "${SCRIPT_DIR}/p5-feed.env"

BASE_URL="${BASE_URL:-http://localhost:18080}"
REGION="${E2E_REGION:-cn}"
APP_VERSION="${E2E_APP_VERSION:-1.0.0-staging}"
DEVICE_ID="${E2E_DEVICE_ID:-qa-device-iphone12-001}"
MEMBER_DEVICE_ID="${E2E_MEMBER_DEVICE_ID:-qa-device-iphone12-002}"
ADMIN_PHONE="${E2E_ADMIN_PHONE:-13800138001}"
ADMIN_CODE="${E2E_ADMIN_CODE:-123456}"
MEMBER_PHONE="${E2E_MEMBER_PHONE:-13800138002}"
MEMBER_CODE="${E2E_MEMBER_CODE:-123456}"
FAMILY_ID="${P5_FAMILY_ID:-fam_e2e_001}"
BABY_ID="${P5_BABY_ID:-bb_e2e_001}"
OBJECT_KEY="${P5_POST_OBJECT_KEY:-family/fam_e2e_001/post/e2e-photo.heic}"
MEMBER_APNS="${P5_MEMBER_APNS_TOKEN:-mock_apns_token_member_e2e}"

CURL_OPTS=(-sS -w "\n%{http_code}" -H "Content-Type: application/json" \
  -H "X-Region: ${REGION}" \
  -H "X-App-Version: ${APP_VERSION}" \
  -H "X-Device-Id: ${DEVICE_ID}")

MEMBER_CURL_OPTS=(-sS -w "\n%{http_code}" -H "Content-Type: application/json" \
  -H "X-Region: ${REGION}" \
  -H "X-App-Version: ${APP_VERSION}" \
  -H "X-Device-Id: ${MEMBER_DEVICE_ID}")

pass=0
fail=0

log() { printf '[p5-e2e] %s\n' "$*" >&2; }

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

json_build() {
  if command -v jq >/dev/null 2>&1; then
    jq -nc "$@"
  else
    echo "{}"
  fi
}

auth_login_verify() {
  local phone="$1" code="$2" label="$3"
  split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/code" \
    -d "{\"phone\":\"${phone}\"}")"
  assert_http "${label} authPhoneSendCode" "200" "${HTTP_CODE}"

  split_response "$(curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/v1/auth/phone/login" \
    -d "{\"phone\":\"${phone}\",\"code\":\"${code}\"}")"
  assert_http "${label} authPhoneLogin" "200" "${HTTP_CODE}"
  assert_body_contains "${label} accessToken" 'accessToken' "${BODY}"
}

# ── 前置 ─────────────────────────────────────────────────────
log "Step 0: GET /health @ ${BASE_URL}"
split_response "$(curl "${CURL_OPTS[@]}" "${BASE_URL}/health")"
assert_http "health" "200" "${HTTP_CODE}"

auth_login_verify "${ADMIN_PHONE}" "${ADMIN_CODE}" "admin"
auth_login_verify "${MEMBER_PHONE}" "${MEMBER_CODE}" "member"
# mock_server 固定 token（避免 $() 捕获 auth_login 时 stdout 污染）
ADMIN_TOKEN="mock_access_token_admin"
MEMBER_TOKEN="mock_access_token_member"
ADMIN_AUTH=(-H "Authorization: Bearer ${ADMIN_TOKEN}")
MEMBER_AUTH=(-H "Authorization: Bearer ${MEMBER_TOKEN}")

# ── 场景 A：智能文案 ─────────────────────────────────────────
log "── Scenario A: Caption Generate ──"
CAPTION_BODY=$(cat <<EOF
{"babyId":"${BABY_ID}","ageDays":312,"play":"ghibli_kid","location":"杭州"}
EOF
)
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/caption/generate" -d "${CAPTION_BODY}")"
assert_http "captionGenerate" "200" "${HTTP_CODE}"
assert_body_contains "caption 3 candidates" '"candidates"' "${BODY}"
assert_body_contains "caption remainingToday" '"remainingToday"' "${BODY}"
CAPTION_TEXT=$(json_field "${BODY}" '.data.candidates[0].text')
HASHTAGS=$(json_field "${BODY}" '.data.candidates[0].hashtags | join(" ")')
[[ -n "${CAPTION_TEXT}" ]] || CAPTION_TEXT="小测 · 第 312 天 · 吉卜力风"

split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/caption/generate" -d "${CAPTION_BODY}")"
assert_http "captionGenerate cache hit" "200" "${HTTP_CODE}"
assert_body_contains "caption cache remaining" '"remainingToday"' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" -H "X-E2E-Scenario: caption_limit" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/caption/generate" -d "${CAPTION_BODY}")"
assert_http "captionGenerate daily limit" "429" "${HTTP_CODE}"
assert_body_contains "caption limit code" 'CAPTION_DAILY_LIMIT' "${BODY}"

# ── 场景 B：UGC 拒绝（发布/评论）────────────────────────────
log "── Scenario B: UGC Rejected ──"
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" -X POST "${BASE_URL}/v1/posts" \
  -d "$(json_build --arg familyId "${FAMILY_ID}" --arg babyId "${BABY_ID}" \
    '{familyId:$familyId, babyIds:[$babyId], caption:"reject_spam 广告", visibility:"family"}')")"
assert_http "postCreate ugc rejected" "422" "${HTTP_CODE}"
assert_body_contains "post ugc POST_AUDIT_REJECTED" 'POST_AUDIT_REJECTED' "${BODY}"

SEED_BODY=$(cat <<EOF
{"familyId":"${FAMILY_ID}","babyIds":["${BABY_ID}"],"caption":"E2E UGC seed","visibility":"family"}
EOF
)
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" -X POST "${BASE_URL}/v1/posts" -d "${SEED_BODY}")"
assert_http "postCreate ugc seed" "200" "${HTTP_CODE}"
SEED_POST=$(json_field "${BODY}" '.data.postId')

split_response "$(curl "${CURL_OPTS[@]}" "${MEMBER_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/posts/${SEED_POST}/comments" \
  -d '{"text":"reject_spam 违规评论"}')"
assert_http "comment ugc rejected" "422" "${HTTP_CODE}"
assert_body_contains "comment ugc POST_AUDIT_REJECTED" 'POST_AUDIT_REJECTED' "${BODY}"

log "Step: POST /v1/e2e/feed/ugc-appeal (mock appeal)"
APPEAL_BODY="$(json_build \
  --arg targetId "${SEED_POST}" \
  '{targetKind:"post", targetId:$targetId, reason:"E2E误判申诉"}')"
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/e2e/feed/ugc-appeal" \
  -d "${APPEAL_BODY}")"
assert_http "ugcAppeal" "200" "${HTTP_CODE}"
assert_body_contains "ugc appealId" 'appealId' "${BODY}"
assert_body_contains "ugc appeal pending" '"status"[[:space:]]*:[[:space:]]*"pending"' "${BODY}"

# ── 场景 C：发布 → 推送 → 浏览 → 互动 → 撤回 ───────────────
log "── Scenario C: Publish → Push → Feed → Engage → Withdraw ──"
split_response "$(curl "${MEMBER_CURL_OPTS[@]}" "${MEMBER_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/notifications/devices" \
  -d "$(json_build \
    --arg deviceId "${MEMBER_DEVICE_ID}" \
    --arg apnsToken "${MEMBER_APNS}" \
    --arg appVersion "${APP_VERSION}" \
    '{deviceId:$deviceId, apnsToken:$apnsToken, appVersion:$appVersion, osVersion:"iOS 17.5", model:"iPhone14,5"}')")"
assert_http "notificationsRegisterDevice member" "200" "${HTTP_CODE}"

PUBLISH_BODY="$(json_build \
  --arg familyId "${FAMILY_ID}" \
  --arg babyId "${BABY_ID}" \
  --arg caption "${CAPTION_TEXT}" \
  --arg objectKey "${OBJECT_KEY}" \
  '{familyId:$familyId, babyIds:[$babyId], caption:$caption, visibility:"family", items:[{kind:"image", objectKey:$objectKey, width:1024, height:1024, deepSynth:true}]}')"
split_response "$(curl "${CURL_OPTS[@]}" -H "X-E2E-Scenario: no_rate_limit" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/posts" -d "${PUBLISH_BODY}")"
assert_http "postCreate happy" "200" "${HTTP_CODE}"
assert_body_contains "post published or audit" '"status"' "${BODY}"
POST_ID=$(json_field "${BODY}" '.data.postId')
[[ -n "${POST_ID}" ]] || { log "FAIL postCreate: no postId"; fail=$((fail + 1)); POST_ID="pst_e2e_fallback"; }

split_response "$(curl "${MEMBER_CURL_OPTS[@]}" "${MEMBER_AUTH[@]}" \
  "${BASE_URL}/v1/notifications?limit=20")"
assert_http "notificationsList member" "200" "${HTTP_CODE}"
assert_body_contains "push FAMILY_ACTIVITY" 'FAMILY_ACTIVITY' "${BODY}"
assert_body_contains "push postId" "${POST_ID}" "${BODY}"
NOTIF_ID=$(json_field "${BODY}" '.data.items[0].id')

split_response "$(curl "${MEMBER_CURL_OPTS[@]}" "${MEMBER_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/notifications/mark-read" \
  -d "{\"ids\":[\"${NOTIF_ID}\"]}")"
assert_http "notificationsMarkRead" "200" "${HTTP_CODE}"
assert_body_contains "mark-read markedCount" '"markedCount"' "${BODY}"

split_response "$(curl "${MEMBER_CURL_OPTS[@]}" "${MEMBER_AUTH[@]}" \
  "${BASE_URL}/v1/feeds/family?familyId=${FAMILY_ID}&limit=20")"
assert_http "feedListFamily" "200" "${HTTP_CODE}"
assert_body_contains "feed contains post" "${POST_ID}" "${BODY}"
assert_body_contains "feed cacheTtlSeconds" '"cacheTtlSeconds"[[:space:]]*:[[:space:]]*60' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${MEMBER_AUTH[@]}" \
  "${BASE_URL}/v1/posts/${POST_ID}")"
assert_http "postGet" "200" "${HTTP_CODE}"
assert_body_contains "post detail caption" 'caption' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${MEMBER_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/posts/${POST_ID}/likes")"
assert_http "postLike" "200" "${HTTP_CODE}"
assert_body_contains "like postId" '"postId"' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${MEMBER_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/posts/${POST_ID}/likes")"
assert_http "postLike duplicate" "200" "${HTTP_CODE}"
assert_body_contains "like duplicate" '"duplicate"[[:space:]]*:[[:space:]]*true' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${MEMBER_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/posts/${POST_ID}/comments" \
  -d '{"text":"外婆来啦，真可爱！"}')"
assert_http "postCreateComment" "200" "${HTTP_CODE}"
COMMENT_ID=$(json_field "${BODY}" '.data.commentId')
assert_body_contains "commentId" 'commentId' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${MEMBER_AUTH[@]}" \
  "${BASE_URL}/v1/posts/${POST_ID}/comments?limit=20")"
assert_http "postListComments" "200" "${HTTP_CODE}"
assert_body_contains "comments list" 'items' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X DELETE "${BASE_URL}/v1/posts/${POST_ID}")"
assert_http "postDelete withdraw" "200" "${HTTP_CODE}"
assert_body_contains "withdraw removed" '"status"[[:space:]]*:[[:space:]]*"removed"' "${BODY}"

split_response "$(curl "${MEMBER_CURL_OPTS[@]}" "${MEMBER_AUTH[@]}" \
  "${BASE_URL}/v1/feeds/family?familyId=${FAMILY_ID}&limit=20")"
assert_http "feed after withdraw" "200" "${HTTP_CODE}"
if echo "${BODY}" | grep -q "${POST_ID}"; then
  log "FAIL feed still contains withdrawn post ${POST_ID}"
  fail=$((fail + 1))
else
  log "PASS feed excludes withdrawn post"
  pass=$((pass + 1))
fi

# ── 场景 D：微信分享（朋友圈 / 好友）────────────────────────
log "── Scenario D: WeChat Share ──"
SHARE_CAPTION="${CAPTION_TEXT}"
WECHAT_TL="$(json_build \
  --arg caption "${SHARE_CAPTION}" \
  --arg objectKey "${OBJECT_KEY}" \
  '{scene:"timeline", caption:$caption, objectKey:$objectKey, deepSynth:true, brandWatermarkRemovable:false}')"
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/e2e/share/wechat" -d "${WECHAT_TL}")"
assert_http "shareWechat timeline" "200" "${HTTP_CODE}"
assert_body_contains "wechat timeline scene" '"scene"[[:space:]]*:[[:space:]]*"timeline"' "${BODY}"
assert_body_contains "wechat thumbnailAdapted" '"thumbnailAdapted"[[:space:]]*:[[:space:]]*true' "${BODY}"
assert_body_contains "wechat deepSynth" '"deepSynthWatermark"[[:space:]]*:[[:space:]]*true' "${BODY}"

WECHAT_SE="$(json_build \
  --arg caption "${SHARE_CAPTION}" \
  --arg objectKey "${OBJECT_KEY}" \
  '{scene:"session", caption:$caption, objectKey:$objectKey, deepSynth:true, brandWatermarkRemovable:true}')"
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/e2e/share/wechat" -d "${WECHAT_SE}")"
assert_http "shareWechat session" "200" "${HTTP_CODE}"
assert_body_contains "wechat session scene" '"scene"[[:space:]]*:[[:space:]]*"session"' "${BODY}"
assert_body_contains "wechat brand watermark off" '"brandWatermarkApplied"[[:space:]]*:[[:space:]]*false' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" -H "X-E2E-Scenario: wechat_not_installed" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/e2e/share/wechat" -d "${WECHAT_SE}")"
assert_http "shareWechat not installed" "422" "${HTTP_CODE}"
assert_body_contains "wechat not installed code" 'SHARE_WECHAT_NOT_INSTALLED' "${BODY}"

# ── 场景 E：系统分享 + 剪贴板文案 ───────────────────────────
log "── Scenario E: System Share ──"
TAGS="${HASHTAGS:-#宝宝成长 #吉卜力}"
SYSTEM_BODY="$(json_build \
  --arg caption "${SHARE_CAPTION}" \
  '{caption:$caption, hashtags:["#宝宝成长","#吉卜力"], destination:"xiaohongshu"}')"
split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/e2e/share/system" -d "${SYSTEM_BODY}")"
assert_http "shareSystem xhs" "200" "${HTTP_CODE}"
assert_body_contains "system clipboardText" 'clipboardText' "${BODY}"
assert_body_contains "system share sheet" '"usesSystemShareSheet"[[:space:]]*:[[:space:]]*true' "${BODY}"
assert_body_contains "system clipboard hint" '"clipboardHintShown"[[:space:]]*:[[:space:]]*true' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" "${ADMIN_AUTH[@]}" \
  -X POST "${BASE_URL}/v1/e2e/share/system" \
  -d "$(json_build --arg caption "${SHARE_CAPTION}" '{caption:$caption, hashtags:["#日常打卡"], destination:"douyin"}')")"
assert_http "shareSystem douyin" "200" "${HTTP_CODE}"
assert_body_contains "system destination douyin" '"destination"[[:space:]]*:[[:space:]]*"douyin"' "${BODY}"

# ── 场景 F：通知类目订阅 ─────────────────────────────────────
log "── Scenario F: Notification Subscriptions ──"
split_response "$(curl "${CURL_OPTS[@]}" "${MEMBER_AUTH[@]}" \
  "${BASE_URL}/v1/notifications/subscriptions")"
assert_http "notificationsGetSubscriptions" "200" "${HTTP_CODE}"
assert_body_contains "subscriptions list" 'subscriptions' "${BODY}"

split_response "$(curl "${CURL_OPTS[@]}" -X PATCH "${BASE_URL}/v1/notifications/subscriptions" \
  "${MEMBER_AUTH[@]}" \
  -d '{"subscriptions":[{"category":"AI_DONE","enabled":false}]}')"
assert_http "notificationsUpdateSubscriptions" "200" "${HTTP_CODE}"
assert_body_contains "AI_DONE disabled" '"category"[[:space:]]*:[[:space:]]*"AI_DONE"' "${BODY}"

# ── 汇总 ─────────────────────────────────────────────────────
log "────────────────────────────────────"
log "Results: ${pass} passed assertions, ${fail} failed"
if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi
log "P5 Feed E2E PASSED: caption · ugc reject+appeal · publish/push/feed/engage/withdraw · wechat · system share · notifications"
exit 0
