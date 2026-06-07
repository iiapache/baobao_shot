#!/usr/bin/env bash
# 对象存储删除事件对账 — T3.2 stub
# 消费 OSS MNS / S3 SQS 删除事件，与 feed-svc / media-svc 元数据对账（当前为 stub，仅结构化日志）
#
# 用法：
#   DELETE_EVENTS_FILE=./fixtures/delete-events.ndjson ./infra/storage/scripts/reconcile-deletes.sh
#   RECONCILE_DRY_RUN=1 ./infra/storage/scripts/reconcile-deletes.sh   # 无输入时输出 stub 心跳
#
# 环境变量：
#   DELETE_EVENTS_FILE   NDJSON 事件文件（每行一条 JSON）
#   DELETE_EVENTS_SOURCE mns|sqs|file（默认 file）
#   RECONCILE_DRY_RUN    1 = 无事件时也输出 RECONCILE 心跳
#   REGION               cn|os（默认 cn）

set -euo pipefail

REGION="${REGION:-cn}"
SOURCE="${DELETE_EVENTS_SOURCE:-file}"
EVENTS_FILE="${DELETE_EVENTS_FILE:-}"
DRY_RUN="${RECONCILE_DRY_RUN:-0}"

processed=0
matched=0
orphan=0
pending=0

log_reconcile() {
  echo "RECONCILE: ts=$(date -u +%Y-%m-%dT%H:%M:%SZ) region=${REGION} source=${SOURCE} $*"
}

# stub：根据 objectKey 前缀推断应对账的服务
infer_owner() {
  local key="$1"
  case "$key" in
    ai-tmp/*) echo "media-svc:upload-session" ;;
    ai-out/*) echo "ai-dispatch-svc:task-output" ;;
    family/*) echo "feed-svc:post-attachment" ;;
    avatar/*) echo "auth-family-svc:avatar" ;;
    caption-cache/*) echo "caption-svc:cache" ;;
    *) echo "unknown" ;;
  esac
}

process_event() {
  local line="$1"
  local bucket object_key event_name event_time

  bucket="$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('bucket',''))" 2>/dev/null || echo "")"
  object_key="$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('objectKey', d.get('key','')))" 2>/dev/null || echo "")"
  event_name="$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('eventName',''))" 2>/dev/null || echo "")"
  event_time="$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('eventTime',''))" 2>/dev/null || echo "")"

  if [[ -z "$object_key" ]]; then
    log_reconcile "status=skip reason=missing_objectKey raw=${line:0:80}"
    return
  fi

  processed=$((processed + 1))
  local owner
  owner="$(infer_owner "$object_key")"

  # stub 对账逻辑：family/ 前缀标记 pending；其余标记 matched（生命周期预期删除）
  case "$object_key" in
    family/*/post/*)
      pending=$((pending + 1))
      log_reconcile "status=pending owner=${owner} bucket=${bucket} key=${object_key} event=${event_name} time=${event_time} note=await_feed_svc_db_check"
      ;;
    ai-tmp/*|ai-out/*|caption-cache/*)
      matched=$((matched + 1))
      log_reconcile "status=matched owner=${owner} bucket=${bucket} key=${object_key} event=${event_name} time=${event_time} note=lifecycle_or_expected_delete"
      ;;
    *)
      orphan=$((orphan + 1))
      log_reconcile "status=orphan owner=${owner} bucket=${bucket} key=${object_key} event=${event_name} time=${event_time} note=manual_review"
      ;;
  esac
}

consume_file() {
  if [[ -z "$EVENTS_FILE" || ! -f "$EVENTS_FILE" ]]; then
    return 1
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    process_event "$line"
  done < "$EVENTS_FILE"
}

consume_mns_stub() {
  log_reconcile "status=stub action=poll_mns note=wire_MNS_consumer_in_T5.5"
  return 1
}

consume_sqs_stub() {
  log_reconcile "status=stub action=poll_sqs note=wire_SQS_consumer_in_T5.5"
  return 1
}

main() {
  log_reconcile "status=start action=reconcile_deletes"

  case "$SOURCE" in
    file)
      if ! consume_file; then
        if [[ "$DRY_RUN" == "1" ]]; then
          log_reconcile "status=heartbeat note=no_events_file stub_ok"
          process_event '{"bucket":"baby-camera-cn","objectKey":"ai-tmp/usr_stub/upl_stub/c1.heic","eventName":"LifecycleExpiration","eventTime":"2026-06-06T00:00:00Z"}'
        else
          log_reconcile "status=idle note=set_DELETE_EVENTS_FILE_or_RECONCILE_DRY_RUN=1"
        fi
      fi
      ;;
    mns) consume_mns_stub || true ;;
    sqs) consume_sqs_stub || true ;;
    *)
      log_reconcile "status=error reason=unknown_source=${SOURCE}"
      exit 1
      ;;
  esac

  log_reconcile "status=done processed=${processed} matched=${matched} pending=${pending} orphan=${orphan}"
  echo "RESULT: RECONCILE processed=${processed} matched=${matched} pending=${pending} orphan=${orphan}"
}

main "$@"
