#!/usr/bin/env bash
# 远端紧急下架 — T7.14 玩法 / 模型 / feature flag kill-switch
#
# 调用 config-svc Admin API（PATCH /v1/admin/*），详见 docs/ops/PHASED_RELEASE_PLAN.md
# 与 T7.11 traffic-shift / rollback 互补：仅下架有问题玩法，避免全服务回滚。
#
# 用法:
#   ./scripts/ops/remote-kill-switch.sh --target play --id ghibli_kid
#   ./scripts/ops/remote-kill-switch.sh --target model --id seedream_style
#   ./scripts/ops/remote-kill-switch.sh --target feature --key ai.play.video_walk
#   ./scripts/ops/remote-kill-switch.sh --set-percent 10
#   ./scripts/ops/remote-kill-switch.sh --target play --id ghibli_kid --dry-run
#
# 环境变量:
#   CONFIG_ADMIN_TOKEN  Admin API 令牌（必填，除 --dry-run 外）
#   CONFIG_SVC_URL      config-svc 基址（默认 http://localhost:8009）

set -euo pipefail

CONFIG_SVC_URL="${CONFIG_SVC_URL:-http://localhost:8009}"
ADMIN_TOKEN="${CONFIG_ADMIN_TOKEN:-}"

TARGET=""
PLAY_ID=""
FEATURE_KEY=""
MODEL_ID=""
SET_PERCENT=""
DRY_RUN=false

# play id → ai.play.* feature key（bash 3.2 兼容，无关联数组）
play_feature_key() {
  case "$1" in
    ghibli_kid)      echo "ai.play.ghibli_kid" ;;
    gpt_portrait)    echo "ai.play.gpt_portrait" ;;
    seedream_style)  echo "ai.play.seedream_style" ;;
    photo_restore)   echo "ai.play.photo_restore" ;;
    video_walk)      echo "ai.play.video_walk" ;;
    year_review_regen) echo "ai.play.year_review_regen" ;;
    smart_caption)   echo "ai.play.smart_caption" ;;
    storybook)       echo "ai.play.storybook" ;;
    cartoon)         echo "ai.play.cartoon" ;;
    ai.play.*|rollout.*) echo "$1" ;;
    *)               echo "ai.play.${1}" ;;
  esac
}

play_catalog_id() {
  case "$1" in
    storybook) echo "play_storybook" ;;
    cartoon)   echo "play_cartoon" ;;
    *)         echo "" ;;
  esac
}

usage() {
  sed -n '2,16p' "$0"
  echo ""
  echo "选项:"
  echo "  --base-url <url>       config-svc 基址（默认 \$CONFIG_SVC_URL）"
  echo "  --target <t>           play | model | feature（与 --set-percent 互斥）"
  echo "  --id <id>              玩法 / 模型短 id（target=play|model 时必填）"
  echo "  --key <key>            feature flag 全名（target=feature 时必填）"
  echo "  --set-percent <n>      更新 rollout.ai_plays_percent 至 n（0–100）"
  echo "  --dry-run              仅打印 curl，不执行"
  exit "${1:-0}"
}

log() { echo "[kill-switch] $*"; }
die() { echo "[kill-switch] ERROR: $*" >&2; exit 1; }

run_curl() {
  local method="$1"
  local url="$2"
  local body="${3:-}"
  local cmd=(curl -sS -X "$method" "$url" -H "Content-Type: application/json")
  if [[ -n "$ADMIN_TOKEN" ]]; then
    cmd+=(-H "X-Admin-Token: ${ADMIN_TOKEN}")
  fi
  if [[ -n "$body" ]]; then
    cmd+=(-d "$body")
  fi
  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] ${cmd[*]}"
    return 0
  fi
  log "执行: ${method} ${url}"
  local resp
  resp="$("${cmd[@]}")"
  echo "$resp"
  if echo "$resp" | grep -q '"code":"OK"'; then
    log "成功"
  else
    die "API 返回非 OK: ${resp}"
  fi
}

disable_feature() {
  local key="$1"
  run_curl PATCH "${CONFIG_SVC_URL}/v1/admin/features/${key}" \
    '{"defaultEnabled":false,"rolloutPercent":0}'
}

disable_play_catalog() {
  local catalog_id="$1"
  run_curl PATCH "${CONFIG_SVC_URL}/v1/admin/plays/${catalog_id}" \
    '{"enabled":false}'
}

set_rollout_percent() {
  local pct="$1"
  [[ "$pct" =~ ^[0-9]+$ ]] || die "无效百分比: ${pct}"
  (( pct >= 0 && pct <= 100 )) || die "百分比须在 0–100: ${pct}"
  run_curl PATCH "${CONFIG_SVC_URL}/v1/admin/features/rollout.ai_plays_percent" \
    "{\"rolloutPercent\":${pct},\"variant\":\"${pct}\"}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url) CONFIG_SVC_URL="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --id) PLAY_ID="$2"; shift 2 ;;
    --key) FEATURE_KEY="$2"; shift 2 ;;
    --model) MODEL_ID="$2"; TARGET="model"; shift 2 ;;
    --set-percent) SET_PERCENT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage 0 ;;
    *) die "未知参数: $1（--help 查看用法）" ;;
  esac
done

if [[ -n "$SET_PERCENT" ]]; then
  [[ -z "$TARGET" ]] || die "--set-percent 不可与 --target 同时使用"
  if [[ "$DRY_RUN" == false && -z "$ADMIN_TOKEN" ]]; then
    die "请设置 CONFIG_ADMIN_TOKEN（或加 --dry-run 预览）"
  fi
  set_rollout_percent "$SET_PERCENT"
  exit 0
fi

[[ -n "$TARGET" ]] || usage 1

if [[ "$DRY_RUN" == false && -z "$ADMIN_TOKEN" ]]; then
  die "请设置 CONFIG_ADMIN_TOKEN（或加 --dry-run 预览）"
fi

case "$TARGET" in
  play)
    [[ -n "$PLAY_ID" ]] || die "--target play 需要 --id"
    feature_key="$(play_feature_key "$PLAY_ID")"
    log "下架玩法 ${PLAY_ID} → feature ${feature_key}"
    disable_feature "$feature_key"
    catalog_id="$(play_catalog_id "$PLAY_ID")"
    if [[ -n "$catalog_id" ]]; then
      log "同步下架 plays 目录 ${catalog_id}"
      disable_play_catalog "$catalog_id"
    fi
    ;;
  model)
    [[ -n "$PLAY_ID" ]] || [[ -n "$MODEL_ID" ]] || die "--target model 需要 --id"
    mid="${MODEL_ID:-$PLAY_ID}"
    feature_key="$(play_feature_key "$mid")"
    log "下架模型路由 ${mid} → feature ${feature_key}"
    disable_feature "$feature_key"
    ;;
  feature)
    [[ -n "$FEATURE_KEY" ]] || die "--target feature 需要 --key"
    log "禁用 feature ${FEATURE_KEY}"
    disable_feature "$FEATURE_KEY"
    ;;
  *)
    die "无效 --target: ${TARGET}（play | model | feature）"
    ;;
esac

log "验证: curl -s -H 'X-Region: cn' ${CONFIG_SVC_URL}/v1/config/features | jq '.data.features'"
