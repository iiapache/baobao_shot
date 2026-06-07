#!/usr/bin/env bash
# P7 E2E（T7.5）：内容审核全链路 — 入参/出参/UGC（图/文/视频）+ 申诉；CN/OS 双版
# 对齐 audit-svc · ai-dispatch appeal · feed UGC · tests/mocks/api/mock_server.py
#
# 本地运行示例（mock 一体化）：
#   python3 tests/mocks/api/mock_server.py &
#   BASE_URL=http://localhost:18080 AUDIT_URL=http://localhost:18080 ./tests/e2e/p7-audit-e2e.sh
#
# 真实 audit-svc（可选）：
#   AUDIT_URL=http://localhost:8005 BASE_URL=http://localhost:18080 ./tests/e2e/p7-audit-e2e.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/e2e.env" ]] && source "${SCRIPT_DIR}/e2e.env"
# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/p7-audit.env" ]] && source "${SCRIPT_DIR}/p7-audit.env"

BASE_URL="${BASE_URL:-http://localhost:18080}"
AUDIT_URL="${AUDIT_URL:-${BASE_URL}}"
REGION="${E2E_REGION:-cn}"
APP_VERSION="${E2E_APP_VERSION:-1.0.0-staging}"
DEVICE_ID="${E2E_DEVICE_ID:-qa-device-p7-audit-001}"
ADMIN_PHONE="${E2E_ADMIN_PHONE:-13800138001}"
ADMIN_CODE="${E2E_ADMIN_CODE:-123456}"
FAMILY_ID="${P7_FAMILY_ID:-fam_e2e_001}"
BABY_ID="${P7_BABY_ID:-bb_e2e_001}"
INPUT_KEY="${P7_INPUT_OBJECT_KEY:-ai-tmp/usr_e2e_admin/e2e-input.heic}"
USER_ID="${P7_USER_ID:-usr_e2e_admin}"

INPUT_SLA_SEC="${P7_INPUT_SLA_SEC:-3}"
OUTPUT_SLA_SEC="${P7_OUTPUT_SLA_SEC:-5}"
APPEAL_SLA_HOURS="${P7_APPEAL_SLA_HOURS:-24}"
POLL_INTERVAL_SEC="${P7_POLL_INTERVAL_SEC:-1}"
POLL_MAX="${P7_POLL_MAX:-12}"

pass=0
fail=0
HTTP_CODE=""
BODY=""

log() { printf '[p7-audit-e2e] %s\n' "$*" >&2; }

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

curl_api() {
  local region="$1"
  shift
  curl -sS -w "\n%{http_code}" -H "Content-Type: application/json" \
    -H "X-Region: ${region}" \
    -H "X-App-Version: ${APP_VERSION}" \
    -H "X-Device-Id: ${DEVICE_ID}" \
    "$@"
}

curl_audit() {
  local region="$1"
  shift
  curl -sS -w "\n%{http_code}" -H "Content-Type: application/json" \
    -H "X-Region: ${region}" \
    "$@"
}

audit_sync() {
  local region="$1" kind="$2" target_ref="$3" payload="$4"
  split_response "$(curl_audit "${region}" -X POST "${AUDIT_URL}/v1/audit/sync" -d "${payload}")"
}

audit_async_enqueue() {
  local region="$1" payload="$2"
  split_response "$(curl_audit "${region}" -X POST "${AUDIT_URL}/v1/audit/async" -d "${payload}")"
}

audit_async_complete() {
  local region="$1" job_id="$2" payload="$3"
  split_response "$(curl_audit "${region}" -X POST "${AUDIT_URL}/v1/audit/async/${job_id}/complete" -d "${payload}")"
}

audit_get_job() {
  local job_id="$1"
  split_response "$(curl_audit "cn" "${AUDIT_URL}/v1/audit/jobs/${job_id}")"
}

run_region_audit_sync_suite() {
  local region="$1"
  local vendor_pattern vendor_reject_pattern
  local start elapsed job_id

  if [[ "${region}" == "cn" ]]; then
    vendor_pattern='aliyun-green'
    vendor_reject_pattern='porn|antispam|terrorism'
  else
    vendor_pattern='openai-moderation|aws-rekognition|cloudflare'
    vendor_reject_pattern='openai_moderation|aws_rekognition|cloudflare_guard'
  fi

  log "── [${region}] Audit Sync: input passed ──"
  start=$(date +%s)
  audit_sync "${region}" "input" "tsk_p7_input_pass_${region}" \
    "$(printf '{"kind":"input","targetRef":"tsk_p7_input_pass_%s","region":"%s","objectKey":"%s","mediaType":"image"}' \
      "${region}" "${region}" "${INPUT_KEY}")"
  elapsed=$(( $(date +%s) - start ))
  assert_http "${region} inputPass" "200" "${HTTP_CODE}"
  assert_body_contains "${region} input status passed" '"status"[[:space:]]*:[[:space:]]*"passed"' "${BODY}"
  assert_body_contains "${region} input vendor" "${vendor_pattern}" "${BODY}"
  assert_sla "${region} input SLA" "${elapsed}" "${INPUT_SLA_SEC}"

  log "── [${region}] Audit Sync: input rejected ──"
  audit_sync "${region}" "input" "tsk_p7_input_reject_${region}" \
    "$(printf '{"kind":"input","targetRef":"tsk_p7_input_reject_%s","region":"%s","objectKey":"reject_porn/%s","mediaType":"image"}' \
      "${region}" "${region}" "${INPUT_KEY}")"
  assert_http "${region} inputReject" "200" "${HTTP_CODE}"
  assert_body_contains "${region} input rejected" '"status"[[:space:]]*:[[:space:]]*"rejected"' "${BODY}"
  assert_body_contains "${region} input reasons" "${vendor_reject_pattern}" "${BODY}"
  job_id=$(json_field "${BODY}" '.jobId')
  [[ -n "${job_id}" ]] || job_id="aud_fallback_input_${region}"

  log "── [${region}] Audit Sync: output passed ──"
  start=$(date +%s)
  audit_sync "${region}" "output" "tsk_p7_output_pass_${region}" \
    "$(printf '{"kind":"output","targetRef":"tsk_p7_output_pass_%s","region":"%s","objectKey":"ai-out/%s/result.heic","mediaType":"image"}' \
      "${region}" "${region}" "${region}")"
  elapsed=$(( $(date +%s) - start ))
  assert_http "${region} outputPass" "200" "${HTTP_CODE}"
  assert_body_contains "${region} output passed" '"result"[[:space:]]*:[[:space:]]*"passed"' "${BODY}"
  assert_sla "${region} output SLA" "${elapsed}" "${OUTPUT_SLA_SEC}"

  log "── [${region}] Audit Sync: output rejected ──"
  audit_sync "${region}" "output" "tsk_p7_output_reject_${region}" \
    "$(printf '{"kind":"output","targetRef":"tsk_p7_output_reject_%s","region":"%s","objectKey":"reject_terror/%s","mediaType":"image"}' \
      "${region}" "${region}" "${region}")"
  assert_http "${region} outputReject" "200" "${HTTP_CODE}"
  assert_body_contains "${region} output rejected" '"status"[[:space:]]*:[[:space:]]*"rejected"' "${BODY}"

  log "── [${region}] Audit Sync: UGC text passed ──"
  audit_sync "${region}" "ugc" "pst_p7_text_pass_${region}" \
    "$(printf '{"kind":"ugc","targetRef":"pst_p7_text_pass_%s","region":"%s","mediaType":"text","text":"宝宝今天很开心"}' \
      "${region}" "${region}")"
  assert_http "${region} ugcTextPass" "200" "${HTTP_CODE}"
  assert_body_contains "${region} ugc text passed" '"status"[[:space:]]*:[[:space:]]*"passed"' "${BODY}"

  log "── [${region}] Audit Sync: UGC text rejected ──"
  audit_sync "${region}" "ugc" "pst_p7_text_reject_${region}" \
    "$(printf '{"kind":"ugc","targetRef":"pst_p7_text_reject_%s","region":"%s","mediaType":"text","text":"reject_spam 广告"}' \
      "${region}" "${region}")"
  assert_http "${region} ugcTextReject" "200" "${HTTP_CODE}"
  assert_body_contains "${region} ugc text rejected" '"status"[[:space:]]*:[[:space:]]*"rejected"' "${BODY}"

  log "── [${region}] Audit Async: UGC image enqueue + complete ──"
  local img_key="family/${FAMILY_ID}/post/e2e-safe-${region}.heic"
  audit_async_enqueue "${region}" \
    "$(printf '{"kind":"ugc","targetRef":"pst_p7_img_%s","region":"%s","mediaType":"image","objectKey":"%s"}' \
      "${region}" "${region}" "${img_key}")"
  assert_http "${region} ugcImageEnqueue" "200" "${HTTP_CODE}"
  assert_body_contains "${region} ugc image pending" '"status"[[:space:]]*:[[:space:]]*"pending"' "${BODY}"
  job_id=$(json_field "${BODY}" '.jobId')
  [[ -n "${job_id}" ]] || job_id="aud_fallback_img_${region}"
  audit_async_complete "${region}" "${job_id}" \
    "$(printf '{"region":"%s","mediaType":"image","objectKey":"%s"}' "${region}" "${img_key}")"
  assert_http "${region} ugcImageComplete" "200" "${HTTP_CODE}"
  assert_body_contains "${region} ugc image passed" '"status"[[:space:]]*:[[:space:]]*"passed"' "${BODY}"

  log "── [${region}] Audit Async: UGC video rejected ──"
  local vid_key="family/${FAMILY_ID}/post/reject_porn_${region}.mp4"
  audit_async_enqueue "${region}" \
    "$(printf '{"kind":"ugc","targetRef":"pst_p7_vid_%s","region":"%s","mediaType":"video","objectKey":"%s"}' \
      "${region}" "${region}" "${vid_key}")"
  assert_http "${region} ugcVideoEnqueue" "200" "${HTTP_CODE}"
  job_id=$(json_field "${BODY}" '.jobId')
  [[ -n "${job_id}" ]] || job_id="aud_fallback_vid_${region}"
  audit_async_complete "${region}" "${job_id}" \
    "$(printf '{"region":"%s","mediaType":"video","objectKey":"%s"}' "${region}" "${vid_key}")"
  assert_http "${region} ugcVideoComplete" "200" "${HTTP_CODE}"
  assert_body_contains "${region} ugc video rejected" '"status"[[:space:]]*:[[:space:]]*"rejected"' "${BODY}"

  log "── [${region}] Appeal on rejected output job ──"
  audit_sync "${region}" "output" "tsk_p7_appeal_${region}" \
    "$(printf '{"kind":"output","targetRef":"tsk_p7_appeal_%s","region":"%s","objectKey":"reject_porn/appeal_%s","mediaType":"image"}' \
      "${region}" "${region}" "${region}")"
  job_id=$(json_field "${BODY}" '.jobId')
  [[ -n "${job_id}" ]] || job_id="aud_fallback_appeal_${region}"
  split_response "$(curl_audit "${region}" -X POST "${AUDIT_URL}/v1/appeals" \
    -d "$(printf '{"auditJobId":"%s","userId":"%s","reason":"E2E误判申诉 %s"}' "${job_id}" "${USER_ID}" "${region}")")"
  assert_http "${region} auditAppeal" "201" "${HTTP_CODE}"
  assert_body_contains "${region} appeal pending" '"status"[[:space:]]*:[[:space:]]*"pending"' "${BODY}"
  assert_body_contains "${region} appealId" 'appealId' "${BODY}"
}

run_region_feed_ugc_suite() {
  local region="$1"
  local token="$2"
  local auth_header=(-H "Authorization: Bearer ${token}")
  local post_id seed_post

  log "── [${region}] Feed UGC: text rejected ──"
  split_response "$(curl_api "${region}" "${auth_header[@]}" -X POST "${BASE_URL}/v1/posts" \
    -d "$(printf '{"familyId":"%s","babyIds":["%s"],"caption":"reject_spam %s","visibility":"family"}' \
      "${FAMILY_ID}" "${BABY_ID}" "${region}")")"
  assert_http "${region} feedTextReject" "422" "${HTTP_CODE}"
  assert_body_contains "${region} feed POST_AUDIT_REJECTED" 'POST_AUDIT_REJECTED' "${BODY}"

  log "── [${region}] Feed UGC: text passed (no media) ──"
  split_response "$(curl_api "${region}" -H "X-E2E-Scenario: no_rate_limit" "${auth_header[@]}" \
    -X POST "${BASE_URL}/v1/posts" \
    -d "$(printf '{"familyId":"%s","babyIds":["%s"],"caption":"P7审核通过 %s","visibility":"family"}' \
      "${FAMILY_ID}" "${BABY_ID}" "${region}")")"
  assert_http "${region} feedTextPass" "200" "${HTTP_CODE}"
  assert_body_contains "${region} feed published" '"status"[[:space:]]*:[[:space:]]*"published"' "${BODY}"
  seed_post=$(json_field "${BODY}" '.data.postId')

  log "── [${region}] Feed UGC: image async audit ──"
  split_response "$(curl_api "${region}" -H "X-E2E-Scenario: no_rate_limit" "${auth_header[@]}" \
    -X POST "${BASE_URL}/v1/posts" \
    -d "$(printf '{"familyId":"%s","babyIds":["%s"],"caption":"P7图文 %s","visibility":"family","items":[{"kind":"image","objectKey":"family/%s/post/safe_%s.heic","width":1024,"height":1024}]}' \
      "${FAMILY_ID}" "${BABY_ID}" "${region}" "${FAMILY_ID}" "${region}")")"
  assert_http "${region} feedImageCreate" "200" "${HTTP_CODE}"
  assert_body_contains "${region} feed image audit" '"status"[[:space:]]*:[[:space:]]*"audit"' "${BODY}"
  post_id=$(json_field "${BODY}" '.data.postId')
  [[ -n "${post_id}" ]] || post_id="pst_fallback_img_${region}"

  split_response "$(curl_api "${region}" "${auth_header[@]}" \
    -X POST "${BASE_URL}/v1/e2e/feed/ugc-media-audit" \
    -d "$(printf '{"postId":"%s"}' "${post_id}")")"
  assert_http "${region} feedImageAuditComplete" "200" "${HTTP_CODE}"
  assert_body_contains "${region} feed image published" '"status"[[:space:]]*:[[:space:]]*"published"' "${BODY}"

  log "── [${region}] Feed UGC: video rejected ──"
  split_response "$(curl_api "${region}" -H "X-E2E-Scenario: no_rate_limit" "${auth_header[@]}" \
    -X POST "${BASE_URL}/v1/posts" \
    -d "$(printf '{"familyId":"%s","babyIds":["%s"],"caption":"P7视频 %s","visibility":"family","items":[{"kind":"video","objectKey":"family/%s/post/reject_porn_%s.mp4","width":1920,"height":1080,"duration":5}]}' \
      "${FAMILY_ID}" "${BABY_ID}" "${region}" "${FAMILY_ID}" "${region}")")"
  assert_http "${region} feedVideoCreate" "200" "${HTTP_CODE}"
  post_id=$(json_field "${BODY}" '.data.postId')
  [[ -n "${post_id}" ]] || post_id="pst_fallback_vid_${region}"

  split_response "$(curl_api "${region}" "${auth_header[@]}" \
    -X POST "${BASE_URL}/v1/e2e/feed/ugc-media-audit" \
    -d "$(printf '{"postId":"%s"}' "${post_id}")")"
  assert_http "${region} feedVideoAuditComplete" "200" "${HTTP_CODE}"
  assert_body_contains "${region} feed video removed" '"status"[[:space:]]*:[[:space:]]*"removed"' "${BODY}"

  log "── [${region}] Feed UGC appeal ──"
  split_response "$(curl_api "${region}" "${auth_header[@]}" \
    -X POST "${BASE_URL}/v1/e2e/feed/ugc-appeal" \
    -d "$(printf '{"targetKind":"post","targetId":"%s","reason":"E2E UGC误判申诉 %s"}' "${seed_post}" "${region}")")"
  assert_http "${region} feedUgcAppeal" "200" "${HTTP_CODE}"
  assert_body_contains "${region} feed appeal pending" '"status"[[:space:]]*:[[:space:]]*"pending"' "${BODY}"
}

run_region_ai_appeal_suite() {
  local region="$1"
  local token="$2"
  local auth_header=(-H "Authorization: Bearer ${token}")
  local create_body task_id poll_body

  log "── [${region}] AI: input rejected + appeal ──"
  split_response "$(curl_api "${region}" -H "X-E2E-Scenario: rejected" "${auth_header[@]}" \
    -X POST "${BASE_URL}/v1/ai/tasks" \
    -d "$(printf '{"play":"ghibli_kid","inputObjectKey":"%s","familyId":"%s","params":{"aspectRatio":"1:1"}}' \
      "${INPUT_KEY}" "${FAMILY_ID}")")"
  assert_http "${region} aiCreateRejected" "200" "${HTTP_CODE}"
  task_id=$(json_field "${BODY}" '.data.taskId')
  [[ -n "${task_id}" ]] || task_id="tsk_e2e_rejected"

  local i=0 state=""
  while [[ "${i}" -lt "${POLL_MAX}" ]]; do
    split_response "$(curl_api "${region}" "${auth_header[@]}" "${BASE_URL}/v1/ai/tasks/${task_id}")"
    assert_http "${region} aiPollRejected $((i + 1))" "200" "${HTTP_CODE}"
    state=$(json_field "${BODY}" '.data.state')
    [[ "${state}" == "rejected" ]] && break
    sleep "${POLL_INTERVAL_SEC}"
    i=$((i + 1))
  done
  assert_body_contains "${region} ai rejected state" '"state"[[:space:]]*:[[:space:]]*"rejected"' "${BODY}"

  split_response "$(curl_api "${region}" "${auth_header[@]}" \
    -X POST "${BASE_URL}/v1/ai/tasks/${task_id}/appeal" \
    -d "$(printf '{"reason":"E2E AI误判申诉 %s"}' "${region}")")"
  assert_http "${region} aiAppeal" "200" "${HTTP_CODE}"
  assert_body_contains "${region} ai appealed" '"state"[[:space:]]*:[[:space:]]*"appealed"' "${BODY}"
  assert_body_contains "${region} ai appealId" 'appealId' "${BODY}"

  log "── [${region}] AI: happy path (output passed) ──"
  split_response "$(curl_api "${region}" "${auth_header[@]}" \
    -X POST "${BASE_URL}/v1/ai/tasks" \
    -d "$(printf '{"play":"ghibli_kid","inputObjectKey":"%s","familyId":"%s","params":{"aspectRatio":"1:1"}}' \
      "${INPUT_KEY}" "${FAMILY_ID}")")"
  assert_http "${region} aiCreateHappy" "200" "${HTTP_CODE}"
  task_id=$(json_field "${BODY}" '.data.taskId')
  [[ -n "${task_id}" ]] || task_id="tsk_e2e_img_happy"

  i=0
  poll_body=""
  while [[ "${i}" -lt "${POLL_MAX}" ]]; do
    split_response "$(curl_api "${region}" "${auth_header[@]}" "${BASE_URL}/v1/ai/tasks/${task_id}")"
    state=$(json_field "${BODY}" '.data.state')
    poll_body="${BODY}"
    [[ "${state}" == "succeeded" ]] && break
    sleep "${POLL_INTERVAL_SEC}"
    i=$((i + 1))
  done
  assert_body_contains "${region} ai succeeded" '"state"[[:space:]]*:[[:space:]]*"succeeded"' "${poll_body}"
  assert_body_contains "${region} ai resultUrl" 'resultUrl' "${poll_body}"
}

# ── Step 0: health ───────────────────────────────────────────
log "Step 0: health checks"
split_response "$(curl_api "${REGION}" "${BASE_URL}/health")"
assert_http "apiHealth" "200" "${HTTP_CODE}"

split_response "$(curl_audit "cn" "${AUDIT_URL}/health")"
assert_http "auditHealth" "200" "${HTTP_CODE}"

# ── Step 1: login ──────────────────────────────────────────────
log "Step 1: auth login"
split_response "$(curl_api "${REGION}" -X POST "${BASE_URL}/v1/auth/phone/code" \
  -d "$(printf '{"phone":"%s"}' "${ADMIN_PHONE}")")"
assert_http "authPhoneSendCode" "200" "${HTTP_CODE}"

split_response "$(curl_api "${REGION}" -X POST "${BASE_URL}/v1/auth/phone/login" \
  -d "$(printf '{"phone":"%s","code":"%s"}' "${ADMIN_PHONE}" "${ADMIN_CODE}")")"
assert_http "authPhoneLogin" "200" "${HTTP_CODE}"
assert_body_contains "login accessToken" 'accessToken' "${BODY}"

TOKEN=$(json_field "${BODY}" '.data.accessToken')
[[ -n "${TOKEN}" ]] || TOKEN="mock_access_token_admin"

# ── Step 2: audit validation errors ──────────────────────────
log "Step 2: audit validation"
audit_sync "cn" "bad" "ref" '{"kind":"unknown","targetRef":"x","region":"cn"}'
assert_http "invalidKind" "400" "${HTTP_CODE}"

audit_sync "xx" "input" "ref" '{"kind":"input","targetRef":"x","region":"invalid"}'
assert_http "invalidRegion" "400" "${HTTP_CODE}"

# ── Step 3-5: CN / OS dual-region suites ───────────────────────
run_region_audit_sync_suite "cn"
run_region_audit_sync_suite "os"

run_region_ai_appeal_suite "cn" "${TOKEN}"
run_region_ai_appeal_suite "os" "${TOKEN}"

run_region_feed_ugc_suite "cn" "${TOKEN}"
run_region_feed_ugc_suite "os" "${TOKEN}"

# ── Step 6: duplicate appeal guard ─────────────────────────────
log "Step 6: duplicate appeal guard"
audit_sync "cn" "output" "tsk_p7_dup_appeal" \
  '{"kind":"output","targetRef":"tsk_p7_dup_appeal","region":"cn","objectKey":"reject_porn/dup","mediaType":"image"}'
DUP_JOB=$(json_field "${BODY}" '.jobId')
[[ -n "${DUP_JOB}" ]] || DUP_JOB="aud_fallback_dup"
split_response "$(curl_audit "cn" -X POST "${AUDIT_URL}/v1/appeals" \
  -d "$(printf '{"auditJobId":"%s","userId":"%s","reason":"首次申诉"}' "${DUP_JOB}" "${USER_ID}")")"
assert_http "appealFirst" "201" "${HTTP_CODE}"
split_response "$(curl_audit "cn" -X POST "${AUDIT_URL}/v1/appeals" \
  -d "$(printf '{"auditJobId":"%s","userId":"%s","reason":"重复申诉"}' "${DUP_JOB}" "${USER_ID}")")"
assert_http "appealDuplicate" "409" "${HTTP_CODE}"

# ── Step 7: OS-specific vendor markers ─────────────────────────
log "Step 7: OS vendor markers"
audit_sync "os" "ugc" "pst_os_openai" \
  '{"kind":"ugc","targetRef":"pst_os_openai","region":"os","mediaType":"text","text":"audit-reject-openai sample"}'
assert_http "osOpenaiReject" "200" "${HTTP_CODE}"
assert_body_contains "os openai reason" 'openai_moderation' "${BODY}"

audit_sync "os" "input" "tsk_os_rek" \
  '{"kind":"input","targetRef":"tsk_os_rek","region":"os","objectKey":"audit-reject-rekognition/key.heic","mediaType":"image"}'
assert_http "osRekognitionReject" "200" "${HTTP_CODE}"
assert_body_contains "os rekognition reason" 'aws_rekognition' "${BODY}"

# ── 汇总 ─────────────────────────────────────────────────────
log "────────────────────────────────────"
log "Results: ${pass} passed assertions, ${fail} failed"
log "Appeal SLA target: ${APPEAL_SLA_HOURS}h (see reports/audit-e2e-report-template.md)"
if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi
log "P7 audit E2E PASSED: input/output/ugc CN+OS · feed · AI appeal · ${pass} assertions"
exit 0
