#!/usr/bin/env bash
# 流量切换脚本 — T7.11 双区域部署演练
# 与 T7.14 App Store 渐进发布并行：端侧放量见 docs/ops/PHASED_RELEASE_PLAN.md
#
# 支持：
#   - Argo Rollouts canary 权重（5 / 25 / 100）
#   - APISIX 网关 upstream 权重（双区域 ack-cn / eks-os）
#   - 蓝绿 promote（--weight 100 --strategy blue-green）
#
# 用法:
#   ./scripts/ops/traffic-shift.sh --service hello --cluster ack-cn --weight 5
#   ./scripts/ops/traffic-shift.sh --service hello --cluster eks-os --weight 25 --namespace staging
#   ./scripts/ops/traffic-shift.sh --service hello --cluster ack-cn --weight 100 --strategy blue-green
#   ./scripts/ops/traffic-shift.sh --dry-run --service hello --cluster ack-cn --weight 5
#
# 环境变量:
#   KUBECTL          kubectl 命令（默认 kubectl）
#   ARGO_ROLLOUTS    argo rollouts 子命令（默认 kubectl argo rollouts）
#   GATEWAY_NS       APISIX 命名空间（默认 gateway）
#   ROUTE_NAME       ApisixRoute 名称（默认 <service>-api）

set -euo pipefail

KUBECTL="${KUBECTL:-kubectl}"
ARGO_ROLLOUTS="${ARGO_ROLLOUTS:-kubectl argo rollouts}"
GATEWAY_NS="${GATEWAY_NS:-gateway}"

SERVICE=""
CLUSTER=""
NAMESPACE="staging"
WEIGHT=""
STRATEGY="canary"   # canary | blue-green
DRY_RUN=false
SKIP_GATEWAY=false
SKIP_ROLLOUT=false
TIMEOUT=300

VALID_WEIGHTS=(5 25 100)

usage() {
  sed -n '2,16p' "$0"
  echo ""
  echo "选项:"
  echo "  --service <name>     服务名（必填）"
  echo "  --cluster <name>     集群：ack-cn | eks-os（必填）"
  echo "  --namespace <ns>     目标命名空间（默认 staging）"
  echo "  --weight <n>         流量权重：5 | 25 | 100（必填）"
  echo "  --strategy <s>       canary（默认）| blue-green"
  echo "  --dry-run            仅打印将执行的命令"
  echo "  --skip-gateway       跳过 APISIX 权重更新"
  echo "  --skip-rollout       跳过 Argo Rollouts 更新"
  echo "  --timeout <sec>      等待 Rollout 就绪超时（默认 300）"
  exit "${1:-0}"
}

log() { echo "[traffic-shift] $*"; }
die() { echo "[traffic-shift] ERROR: $*" >&2; exit 1; }

run_cmd() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] $*"
  else
    log "执行: $*"
    eval "$@"
  fi
}

validate_weight() {
  local w="$1"
  local valid=false
  for v in "${VALID_WEIGHTS[@]}"; do
    if [[ "$w" == "$v" ]]; then
      valid=true
      break
    fi
  done
  [[ "$valid" == true ]] || die "无效权重 ${w}，仅支持: ${VALID_WEIGHTS[*]}"
}

switch_context() {
  log "切换集群上下文 → ${CLUSTER}"
  run_cmd "${KUBECTL} config use-context ${CLUSTER}"
}

shift_rollout_canary() {
  local w="$1"
  log "Argo Rollouts canary 权重 → ${w}%"

  if [[ "$DRY_RUN" == false ]] && ! ${KUBECTL} get rollout "${SERVICE}" -n "${NAMESPACE}" &>/dev/null; then
    die "Rollout ${SERVICE} 在 ${NAMESPACE} 不存在；请先应用 infra/argocd/rollout/"
  fi

  run_cmd "${ARGO_ROLLOUTS} set image ${SERVICE} ${SERVICE}=registry.example.com/baobao/${SERVICE}:latest -n ${NAMESPACE} 2>/dev/null || true"
  run_cmd "${ARGO_ROLLOUTS} set weight ${SERVICE} ${w} -n ${NAMESPACE}"

  if [[ "$DRY_RUN" == false ]]; then
    log "等待 Rollout 权重 ${w}% 生效（超时 ${TIMEOUT}s）..."
    if ! timeout "${TIMEOUT}" ${ARGO_ROLLOUTS} status "${SERVICE}" -n "${NAMESPACE}" --timeout "${TIMEOUT}s" 2>/dev/null; then
      log "WARN: Rollout status 超时，请手动检查: ${ARGO_ROLLOUTS} get rollout ${SERVICE} -n ${NAMESPACE}"
    fi
  fi
}

promote_blue_green() {
  log "蓝绿发布 promote → active"
  if [[ "$DRY_RUN" == false ]] && ! ${KUBECTL} get rollout "${SERVICE}" -n "${NAMESPACE}" &>/dev/null; then
    die "Rollout ${SERVICE} 在 ${NAMESPACE} 不存在"
  fi
  run_cmd "${ARGO_ROLLOUTS} promote ${SERVICE} -n ${NAMESPACE}"
  if [[ "$DRY_RUN" == false ]]; then
    timeout "${TIMEOUT}" ${ARGO_ROLLOUTS} status "${SERVICE}" -n "${NAMESPACE}" --timeout "${TIMEOUT}s" || true
  fi
}

shift_gateway_weight() {
  local w="$1"
  local route_name="${ROUTE_NAME:-${SERVICE}-api}"
  local stable_weight=$((100 - w))

  log "APISIX 网关权重 → canary=${w}% stable=${stable_weight}% (route=${route_name})"

  # 通过 patch ApisixRoute upstream 权重（需 apisix ingress controller）
  local patch
  patch=$(cat <<EOF
{
  "metadata": {
    "annotations": {
      "baobao.io/canary-weight": "${w}",
      "baobao.io/canary-shift-at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
  },
  "spec": {
    "http": [{
      "backends": [
        {"serviceName": "${SERVICE}-canary", "servicePort": 80, "weight": ${w}},
        {"serviceName": "${SERVICE}-stable", "servicePort": 80, "weight": ${stable_weight}}
      ]
    }]
  }
}
EOF
)

  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] ${KUBECTL} patch apisixroute ${route_name} -n ${GATEWAY_NS} --type=merge -p '<json>'"
    return
  fi

  if ${KUBECTL} get apisixroute "${route_name}" -n "${GATEWAY_NS}" &>/dev/null; then
    echo "${patch}" | ${KUBECTL} patch apisixroute "${route_name}" -n "${GATEWAY_NS}" --type=merge -p "$(cat)"
    log "ApisixRoute ${route_name} 已更新"
  else
    log "WARN: ApisixRoute ${route_name} 不存在于 ${GATEWAY_NS}，跳过网关层（仅 Rollout 层生效）"
  fi
}

verify_health() {
  local host
  case "${CLUSTER}" in
    ack-cn) host="${GATEWAY_HOST_CN:-staging-api-cn.example.com}" ;;
    eks-os) host="${GATEWAY_HOST_OS:-staging-api-os.example.com}" ;;
    *) host="${GATEWAY_HOST:-staging-api-cn.example.com}" ;;
  esac

  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] curl -sS -o /dev/null -w '%{http_code}' https://${host}/health"
    return
  fi

  if command -v curl >/dev/null 2>&1; then
    local code
    code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 \
      "https://${host}/health" 2>/dev/null || echo "000")
    if [[ "$code" == "200" ]]; then
      log "健康检查通过 → ${host}/health HTTP ${code}"
    else
      log "WARN: 健康检查 ${host}/health → HTTP ${code}（网关未就绪时可忽略）"
    fi
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --service) SERVICE="$2"; shift 2 ;;
    --cluster) CLUSTER="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --weight) WEIGHT="$2"; shift 2 ;;
    --strategy) STRATEGY="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --skip-gateway) SKIP_GATEWAY=true; shift ;;
    --skip-rollout) SKIP_ROLLOUT=true; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) die "未知参数: $1（--help 查看用法）" ;;
  esac
done

[[ -n "$SERVICE" ]] || die "缺少 --service"
[[ -n "$CLUSTER" ]] || die "缺少 --cluster"
[[ -n "$WEIGHT" ]] || die "缺少 --weight"
validate_weight "$WEIGHT"

case "$CLUSTER" in
  ack-cn|eks-os) ;;
  *) die "无效集群 ${CLUSTER}，仅支持 ack-cn | eks-os" ;;
esac

case "$STRATEGY" in
  canary|blue-green) ;;
  *) die "无效策略 ${STRATEGY}，仅支持 canary | blue-green" ;;
esac

START_TS=$(date +%s)
log "开始流量切换: service=${SERVICE} cluster=${CLUSTER} ns=${NAMESPACE} weight=${WEIGHT}% strategy=${STRATEGY}"

switch_context

if [[ "$SKIP_ROLLOUT" == false ]]; then
  if [[ "$STRATEGY" == "blue-green" && "$WEIGHT" == "100" ]]; then
    promote_blue_green
  else
    shift_rollout_canary "$WEIGHT"
  fi
fi

if [[ "$SKIP_GATEWAY" == false && "$STRATEGY" == "canary" ]]; then
  shift_gateway_weight "$WEIGHT"
fi

verify_health

ELAPSED=$(( $(date +%s) - START_TS ))
log "流量切换完成，耗时 ${ELAPSED}s（目标权重 ${WEIGHT}%）"
