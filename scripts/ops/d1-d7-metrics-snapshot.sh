#!/usr/bin/env bash
# D1/D7 关键指标快照 — T7.15
#
# 从 Prometheus HTTP API（及可选 Grafana Annotations）拉取 P7 完成判定相关指标，
# 输出 JSON 快照供 D1_D7_MONITORING_CHECKLIST 填写。
#
# 用法:
#   ./scripts/ops/d1-d7-metrics-snapshot.sh --day 1
#   ./scripts/ops/d1-d7-metrics-snapshot.sh --day 7 --region cn --output snapshots/d7-cn.json
#   ./scripts/ops/d1-d7-metrics-snapshot.sh --day 1 --mock          # 无监控栈 stub
#   ./scripts/ops/d1-d7-metrics-snapshot.sh --day 1 --dry-run       # 仅打印 PromQL
#
# 环境变量:
#   PROMETHEUS_URL   Prometheus base URL（默认 http://localhost:9090）
#   GRAFANA_URL      Grafana base URL（可选，用于 annotation 标记）
#   GRAFANA_TOKEN    Grafana API token（可选）
#   CURL             curl 命令（默认 curl）
#   MOCK             设为 1 等同 --mock

set -euo pipefail

CURL="${CURL:-curl}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
GRAFANA_URL="${GRAFANA_URL:-}"
GRAFANA_TOKEN="${GRAFANA_TOKEN:-}"

DAY=""
REGION="all"
OUTPUT=""
MOCK=false
DRY_RUN=false

# key @DELIM@ promql @DELIM@ threshold @DELIM@ unit @DELIM@ category
METRIC_DEFINITIONS=(
  'gateway_5xx_rate@DELIM@sum(rate(apisix_http_status{code=~"5.."}[5m])) / sum(rate(apisix_http_status[5m]))@DELIM@<0.001@DELIM@ratio@DELIM@api'
  'feed_p95_seconds@DELIM@histogram_quantile(0.95, sum(rate(babycamera_feed_request_duration_seconds_bucket{cache_hit="true"}[5m])) by (le))@DELIM@<0.5@DELIM@seconds@DELIM@api'
  'ai_success_rate@DELIM@sum(rate(babycamera_ai_task_total{status="success"}[10m])) / sum(rate(babycamera_ai_task_total{status=~"success|failed|rejected|timeout"}[10m]))@DELIM@>=0.95@DELIM@ratio@DELIM@ai'
  'ai_image_p95_seconds@DELIM@histogram_quantile(0.95, sum(rate(babycamera_ai_task_duration_seconds_bucket{capability="image"}[5m])) by (le))@DELIM@<60@DELIM@seconds@DELIM@ai'
  'ai_video_p95_seconds@DELIM@histogram_quantile(0.95, sum(rate(babycamera_ai_task_duration_seconds_bucket{capability="video"}[5m])) by (le))@DELIM@<300@DELIM@seconds@DELIM@ai'
  'iap_verify_success_rate@DELIM@sum(rate(babycamera_iap_verify_total{result="success"}[5m])) / sum(rate(babycamera_iap_verify_total[5m]))@DELIM@>=0.995@DELIM@ratio@DELIM@commerce'
  'credit_reconciliation_discrepancy@DELIM@sum(increase(babycamera_credit_reconciliation_discrepancy_total[24h]))@DELIM@==0@DELIM@count@DELIM@commerce'
  'apns_failure_rate@DELIM@sum(rate(babycamera_apns_push_total{result=~"failed|unregistered"}[10m])) / sum(rate(babycamera_apns_push_total[10m]))@DELIM@<0.01@DELIM@ratio@DELIM@push'
  'audit_error_rate@DELIM@sum(rate(babycamera_audit_request_total{result="error"}[5m])) / sum(rate(babycamera_audit_request_total[5m]))@DELIM@<0.01@DELIM@ratio@DELIM@audit'
  'service_5xx_rate@DELIM@sum(rate(traces_spanmetrics_calls_total{http_status_code=~"5..",service_name=~"feed-svc|auth-family-svc|ai-dispatch-svc"}[5m])) / sum(rate(traces_spanmetrics_calls_total{service_name=~"feed-svc|auth-family-svc|ai-dispatch-svc"}[5m]))@DELIM@<0.001@DELIM@ratio@DELIM@api'
)

usage() {
  sed -n '2,14p' "$0"
  echo ""
  echo "选项:"
  echo "  --day <1|7>         上线后第几天（必填）"
  echo "  --region <cn|os|all> 区域标签过滤（默认 all）"
  echo "  --output <path>     写入 JSON 文件（默认 stdout）"
  echo "  --mock              输出 stub 数据，不请求 API"
  echo "  --dry-run           仅打印 PromQL，不查询"
  exit "${1:-0}"
}

log() { echo "[d1-d7-snapshot] $*" >&2; }
die() { echo "[d1-d7-snapshot] ERROR: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --day) DAY="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --mock) MOCK=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) die "未知参数: $1" ;;
  esac
done

[[ -n "$DAY" ]] || die "缺少 --day（1 或 7）"
case "$DAY" in
  1|7) ;;
  *) die "--day 必须为 1 或 7" ;;
esac

case "$REGION" in
  cn|os|all) ;;
  *) die "--region 必须为 cn、os 或 all" ;;
esac

if [[ "${MOCK:-0}" == "1" ]]; then
  MOCK=true
fi

parse_metric_line() {
  local line="$1"
  MET_KEY="${line%%@DELIM@*}"
  local rest="${line#*@DELIM@}"
  MET_PROMQL="${rest%%@DELIM@*}"
  rest="${rest#*@DELIM@}"
  MET_THRESHOLD="${rest%%@DELIM@*}"
  rest="${rest#*@DELIM@}"
  MET_UNIT="${rest%%@DELIM@*}"
  MET_CATEGORY="${rest#*@DELIM@}"
}

region_filter() {
  local q="$1"
  if [[ "$REGION" == "all" ]]; then
    echo "$q"
  else
    echo "${q}" | sed "s/\[5m\]/[5m],region=\"${REGION}\"/g" | sed "s/\[10m\]/[10m],region=\"${REGION}\"/g" | sed "s/\[24h\]/[24h],region=\"${REGION}\"/g"
  fi
}

prom_query() {
  local query="$1"
  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] PromQL: ${query}"
    return 0
  fi
  if [[ "$MOCK" == true ]]; then
    return 0
  fi

  local encoded
  encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$query" 2>/dev/null \
    || echo "$query" | sed 's/ /%20/g; s/{/%7B/g; s/}/%7D/g; s/"/%22/g; s/|/%7C/g; s/=/%3D/g; s/+/%2B/g; s/\//%2F/g; s/\./%2E/g; s/:/%3A/g; s/,/%2C/g; s/\^/%5E/g; s/(/%28/g; s/)/%29/g')

  local resp
  resp=$("${CURL}" -sS --max-time 30 \
    "${PROMETHEUS_URL}/api/v1/query?query=${encoded}" 2>/dev/null || echo '{"status":"error"}')

  if command -v jq >/dev/null 2>&1; then
    local status
    status=$(echo "$resp" | jq -r '.status // "error"')
    if [[ "$status" != "success" ]]; then
      echo "null"
      return 1
    fi
    echo "$resp" | jq -r '.data.result[0].value[1] // "null"'
  else
    echo "$resp" | grep -o '"value":\[[^]]*\]' | head -1 | grep -o '[0-9.eE+-]*$' || echo "null"
  fi
}

mock_value() {
  local key="$1"
  case "$key" in
    gateway_5xx_rate) echo "0.0003" ;;
    feed_p95_seconds) echo "0.42" ;;
    ai_success_rate) echo "0.967" ;;
    ai_image_p95_seconds) echo "48.2" ;;
    ai_video_p95_seconds) echo "185.0" ;;
    iap_verify_success_rate) echo "0.9982" ;;
    credit_reconciliation_discrepancy) echo "0" ;;
    apns_failure_rate) echo "0.004" ;;
    audit_error_rate) echo "0.002" ;;
    service_5xx_rate) echo "0.0002" ;;
    *) echo "null" ;;
  esac
}

check_threshold() {
  local value="$1"
  local threshold="$2"
  if [[ "$value" == "null" || -z "$value" ]]; then
    echo "unknown"
    return
  fi
  case "$threshold" in
    \<*)
      awk -v v="$value" -v t="${threshold#<}" 'BEGIN { print (v < t + 0) ? "pass" : "fail" }'
      ;;
    \<=*)
      awk -v v="$value" -v t="${threshold#<=}" 'BEGIN { print (v <= t + 0) ? "pass" : "fail" }'
      ;;
    \>*=*)
      awk -v v="$value" -v t="${threshold#>=}" 'BEGIN { print (v >= t + 0) ? "pass" : "fail" }'
      ;;
    \==*)
      awk -v v="$value" -v t="${threshold#==}" 'BEGIN { print (v == t + 0) ? "pass" : "fail" }'
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

json_escape() {
  python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$1" 2>/dev/null || echo "\"$1\""
}

emit_json() {
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  if [[ "$DRY_RUN" == true ]]; then
    for line in "${METRIC_DEFINITIONS[@]}"; do
      parse_metric_line "$line"
      region_filter "$MET_PROMQL"
    done
    return 0
  fi

  local pass_count=0 fail_count=0 unknown_count=0
  local metrics_json=""
  local first=true

  for line in "${METRIC_DEFINITIONS[@]}"; do
    parse_metric_line "$line"
    local q
    q=$(region_filter "$MET_PROMQL")
    local val
    if [[ "$MOCK" == true ]]; then
      val=$(mock_value "$MET_KEY")
    else
      val=$(prom_query "$q" || echo "null")
    fi
    local status
    status=$(check_threshold "$val" "$MET_THRESHOLD")

    case "$status" in
      pass) pass_count=$((pass_count + 1)) ;;
      fail) fail_count=$((fail_count + 1)) ;;
      *) unknown_count=$((unknown_count + 1)) ;;
    esac

    [[ "$first" == true ]] || metrics_json+=","
    first=false
    metrics_json+="\"${MET_KEY}\":{"
    metrics_json+="\"value\":${val},"
    metrics_json+="\"unit\":$(json_escape "$MET_UNIT"),"
    metrics_json+="\"category\":$(json_escape "$MET_CATEGORY"),"
    metrics_json+="\"threshold\":$(json_escape "$MET_THRESHOLD"),"
    metrics_json+="\"status\":$(json_escape "$status"),"
    metrics_json+="\"promql\":$(json_escape "$q")"
    metrics_json+="}"
  done

  local json
  json=$(cat <<EOF
{
  "snapshot_version": "1.0",
  "task": "T7.15",
  "day": ${DAY},
  "region": "${REGION}",
  "captured_at": "${ts}",
  "source": "$([[ "$MOCK" == true ]] && echo mock || echo prometheus)",
  "prometheus_url": "${PROMETHEUS_URL}",
  "metrics": {${metrics_json}},
  "summary": {"pass": ${pass_count}, "fail": ${fail_count}, "unknown": ${unknown_count}},
  "checklist": "docs/ops/D1_D7_MONITORING_CHECKLIST.md",
  "playbook": "docs/ops/INCIDENT_RESPONSE_PLAYBOOK.md"
}
EOF
)

  if [[ -n "$OUTPUT" ]]; then
    mkdir -p "$(dirname "$OUTPUT")"
    if command -v jq >/dev/null 2>&1; then
      echo "$json" | jq '.' > "$OUTPUT"
    else
      echo "$json" > "$OUTPUT"
    fi
    log "已写入 ${OUTPUT}"
  else
    if command -v jq >/dev/null 2>&1; then
      echo "$json" | jq '.'
    else
      echo "$json"
    fi
  fi
}

grafana_annotate() {
  [[ -n "$GRAFANA_URL" && -n "$GRAFANA_TOKEN" && "$MOCK" == false && "$DRY_RUN" == false ]] || return 0

  local ts ms text
  ts=$(date +%s)
  ms=$(( ts * 1000 ))
  text="D${DAY} metrics snapshot (region=${REGION})"

  log "写入 Grafana annotation（可选）"
  "${CURL}" -sS -X POST "${GRAFANA_URL}/api/annotations" \
    -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"time\":${ms},\"tags\":[\"d1-d7\",\"day-${DAY}\",\"${REGION}\"],\"text\":\"${text}\"}" \
    >/dev/null 2>&1 || log "WARN: Grafana annotation 失败（可忽略）"
}

log "开始 D${DAY} 指标快照 region=${REGION} mock=${MOCK}"
emit_json
grafana_annotate
log "完成 ✓"
