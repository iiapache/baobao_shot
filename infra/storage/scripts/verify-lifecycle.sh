#!/usr/bin/env bash
# T3.2 生命周期配置验收 — 校验仓库内规则文件 + 可选远端桶配置
# 用法：
#   ./infra/storage/scripts/verify-lifecycle.sh
#   VERIFY_REMOTE=1 ./infra/storage/scripts/verify-lifecycle.sh
#
# 期望：RESULT: PASS (N/N checks)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

OSS_LIFECYCLE="${STORAGE_DIR}/oss-cn/lifecycle-rules.xml"
S3_LIFECYCLE="${STORAGE_DIR}/s3-os/lifecycle-rules.json"

PASS=0
FAIL=0

log_pass() { echo "[PASS] $*"; PASS=$((PASS + 1)); }
log_fail() { echo "[FAIL] $*" >&2; FAIL=$((FAIL + 1)); }

require_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    log_pass "file exists: $(basename "$f")"
  else
    log_fail "missing file: $f"
  fi
}

check_oss_rule() {
  local id="$1"
  local prefix="$2"
  local expect_expiration="${3:-}"
  local expect_transition="${4:-}"

  if ! grep -q "<ID>${id}</ID>" "$OSS_LIFECYCLE"; then
    log_fail "OSS rule missing ID: ${id}"
    return
  fi

  local block
  block="$(awk -v id="$id" '
    $0 ~ "<ID>" id "</ID>" { found=1 }
    found { print }
    found && $0 ~ "</Rule>" { exit }
  ' "$OSS_LIFECYCLE")"

  if echo "$block" | grep -q "<Prefix>${prefix}</Prefix>"; then
    log_pass "OSS ${id}: prefix=${prefix}"
  else
    log_fail "OSS ${id}: expected prefix ${prefix}"
  fi

  if [[ -n "$expect_expiration" ]]; then
    if echo "$block" | grep -A2 "<Expiration>" | grep -q "<Days>${expect_expiration}</Days>"; then
      log_pass "OSS ${id}: expiration=${expect_expiration}d"
    else
      log_fail "OSS ${id}: expected expiration ${expect_expiration}d"
    fi
  elif echo "$block" | grep -q "<Expiration>"; then
    log_fail "OSS ${id}: should NOT have Expiration"
  else
    log_pass "OSS ${id}: no expiration (long-term)"
  fi

  if [[ -n "$expect_transition" ]]; then
    if echo "$block" | grep -q "<Transition>"; then
      log_pass "OSS ${id}: has storage transition"
    else
      log_fail "OSS ${id}: expected Transition block"
    fi
  fi
}

check_s3_rules() {
  python3 <<PY
import json, sys
path = "${S3_LIFECYCLE}"
with open(path) as f:
    cfg = json.load(f)
checks = [
    ("expire-ai-tmp-24h", "ai-tmp/", "1", False),
    ("expire-ai-out-30d", "ai-out/", "30", False),
    ("family-long-term-ia-transition", "family/", "", True),
]
rules = {r["ID"]: r for r in cfg.get("Rules", [])}
for rid, prefix, exp, need_trans in checks:
    r = rules.get(rid)
    if not r:
        print(f"FAIL:S3 rule missing: {rid}")
        continue
    if r.get("Filter", {}).get("Prefix") != prefix:
        print(f"FAIL:S3 {rid}: bad prefix")
        continue
    print(f"PASS:S3 {rid}: prefix={prefix}")
    exp_days = r.get("Expiration", {}).get("Days")
    if exp:
        if str(exp_days) != exp:
            print(f"FAIL:S3 {rid}: expiration want {exp} got {exp_days}")
        else:
            print(f"PASS:S3 {rid}: expiration={exp}d")
    elif exp_days is not None:
        print(f"FAIL:S3 {rid}: should not expire")
    else:
        print(f"PASS:S3 {rid}: no expiration (long-term)")
    if need_trans and not r.get("Transitions"):
        print(f"FAIL:S3 {rid}: missing transitions")
    elif need_trans:
        print(f"PASS:S3 {rid}: has storage transition")
PY
}

verify_local_configs() {
  echo "=== T3.2 本地 lifecycle 规则校验 ==="
  require_file "$OSS_LIFECYCLE"
  require_file "$S3_LIFECYCLE"

  check_oss_rule "expire-ai-tmp-24h" "ai-tmp/" "1"
  check_oss_rule "expire-ai-out-30d" "ai-out/" "30"
  check_oss_rule "family-long-term-ia-transition" "family/" "" "yes"

  echo "--- S3 JSON ---"
  while IFS= read -r line; do
    case "$line" in
      PASS:*) log_pass "${line#PASS:}" ;;
      FAIL:*) log_fail "${line#FAIL:}" ;;
    esac
  done < <(check_s3_rules)

  for f in \
    "${STORAGE_DIR}/oss-cn/event-notification.yaml" \
    "${STORAGE_DIR}/s3-os/event-notification.json.template" \
    "${STORAGE_DIR}/scripts/reconcile-deletes.sh"
  do
    require_file "$f"
  done

  if grep -q "ObjectRemoved" "${STORAGE_DIR}/oss-cn/event-notification.yaml"; then
    log_pass "OSS event-notification includes ObjectRemoved"
  else
    log_fail "OSS event-notification missing ObjectRemoved"
  fi
  if grep -q "s3:ObjectRemoved" "${STORAGE_DIR}/s3-os/event-notification.json.template"; then
    log_pass "S3 event-notification includes ObjectRemoved"
  else
    log_fail "S3 event-notification missing ObjectRemoved"
  fi
}

verify_remote() {
  echo "=== 远端桶 lifecycle（可选）==="
  local bucket="${OSS_BUCKET_NAME:-baby-camera-cn}"
  if command -v ossutil &>/dev/null; then
    if ossutil lifecycle --method get "oss://${bucket}/" 2>/dev/null | grep -q "expire-ai-tmp-24h"; then
      log_pass "remote OSS lifecycle contains expire-ai-tmp-24h"
    else
      log_fail "remote OSS lifecycle missing expire-ai-tmp-24h (或未配置凭据)"
    fi
  else
    echo "SKIP: ossutil not installed for remote OSS check"
  fi

  bucket="${AWS_BUCKET_NAME:-baby-camera-os}"
  local region="${AWS_REGION:-ap-southeast-1}"
  if command -v aws &>/dev/null; then
    if aws s3api get-bucket-lifecycle-configuration --bucket "$bucket" --region "$region" 2>/dev/null \
      | grep -q "expire-ai-tmp-24h"; then
      log_pass "remote S3 lifecycle contains expire-ai-tmp-24h"
    else
      log_fail "remote S3 lifecycle missing expire-ai-tmp-24h (或未配置凭据)"
    fi
  else
    echo "SKIP: aws CLI not installed for remote S3 check"
  fi
}

main() {
  verify_local_configs
  if [[ "${VERIFY_REMOTE:-0}" == "1" ]]; then
    verify_remote
  fi

  local total=$((PASS + FAIL))
  echo
  if (( FAIL > 0 )); then
    echo "RESULT: FAIL (${PASS}/${total} passed, ${FAIL} failed)" >&2
    exit 1
  fi
  echo "RESULT: PASS (${PASS}/${total} checks)"
}

main "$@"
