#!/usr/bin/env bash
# 单服务一键回滚 — T7.11 验收：5 分钟内完成
#
# 回滚路径（按优先级）：
#   1. Argo Rollouts abort + undo（canary / blue-green 进行中）
#   2. ArgoCD Application rollback（GitOps 上一 revision）
#   3. kubectl rollout undo（标准 Deployment 兜底）
#
# 用法:
#   ./scripts/ops/rollback-service.sh --service hello --cluster ack-cn
#   ./scripts/ops/rollback-service.sh --service hello --cluster eks-os --namespace staging
#   ./scripts/ops/rollback-service.sh --service hello --cluster ack-cn --revision 2
#   ./scripts/ops/rollback-service.sh --dry-run --service hello --cluster ack-cn
#
# 环境变量:
#   KUBECTL       kubectl 命令（默认 kubectl）
#   ARGOCD        argocd CLI（默认 argocd）
#   ARGO_ROLLOUTS argo rollouts 子命令（默认 kubectl argo rollouts）
#   ROLLBACK_SLA  回滚 SLA 秒数（默认 300 = 5 分钟）

set -euo pipefail

KUBECTL="${KUBECTL:-kubectl}"
ARGOCD="${ARGOCD:-argocd}"
ARGO_ROLLOUTS="${ARGO_ROLLOUTS:-kubectl argo rollouts}"
ROLLBACK_SLA="${ROLLBACK_SLA:-300}"

SERVICE=""
CLUSTER=""
NAMESPACE="staging"
ENVIRONMENT="staging"
REVISION=""        # ArgoCD history id，空 = 上一版本
DRY_RUN=false
SKIP_GATEWAY=true  # 回滚默认同步恢复网关权重为 0% canary
FORCE_DEPLOYMENT=false

usage() {
  sed -n '2,14p' "$0"
  echo ""
  echo "选项:"
  echo "  --service <name>       服务名（必填）"
  echo "  --cluster <name>       集群：ack-cn | eks-os（必填）"
  echo "  --namespace <ns>       目标命名空间（默认 staging）"
  echo "  --environment <env>    环境标签（默认 staging，用于 ArgoCD app 名）"
  echo "  --revision <id>        ArgoCD history revision（默认上一版）"
  echo "  --dry-run              仅打印将执行的命令"
  echo "  --force-deployment     跳过 Rollouts/ArgoCD，直接 kubectl rollout undo"
  echo "  --restore-gateway      回滚后将 APISIX canary 权重归零"
  exit "${1:-0}"
}

log() { echo "[rollback] $*"; }
die() { echo "[rollback] ERROR: $*" >&2; exit 1; }

run_cmd() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] $*"
  else
    log "执行: $*"
    eval "$@"
  fi
}

check_sla() {
  local start="$1"
  local elapsed=$(( $(date +%s) - start ))
  if [[ "$elapsed" -gt "$ROLLBACK_SLA" ]]; then
    die "回滚超时 ${elapsed}s > SLA ${ROLLBACK_SLA}s，请人工介入"
  fi
  log "回滚耗时 ${elapsed}s（SLA ${ROLLBACK_SLA}s）"
}

switch_context() {
  log "切换集群上下文 → ${CLUSTER}"
  run_cmd "${KUBECTL} config use-context ${CLUSTER}"
}

rollback_rollout() {
  if [[ "$DRY_RUN" == true ]]; then
    log "Argo Rollouts abort + undo（dry-run）"
    echo "[dry-run] ${ARGO_ROLLOUTS} abort ${SERVICE} -n ${NAMESPACE}"
    echo "[dry-run] ${ARGO_ROLLOUTS} undo ${SERVICE} -n ${NAMESPACE}"
    return 0
  fi

  if ! ${KUBECTL} get rollout "${SERVICE}" -n "${NAMESPACE}" &>/dev/null; then
    log "无 Rollout 资源，跳过 Rollouts 回滚"
    return 1
  fi

  log "Argo Rollouts abort（停止 canary 推进）"
  run_cmd "${ARGO_ROLLOUTS} abort ${SERVICE} -n ${NAMESPACE}" || true

  log "Argo Rollouts undo（回退到 stable revision）"
  run_cmd "${ARGO_ROLLOUTS} undo ${SERVICE} -n ${NAMESPACE}"

  if [[ "$DRY_RUN" == false ]]; then
    timeout 120 ${ARGO_ROLLOUTS} status "${SERVICE}" -n "${NAMESPACE}" --timeout 120s || true
  fi
  return 0
}

rollback_argocd() {
  local app_name="${SERVICE}-${ENVIRONMENT}-${CLUSTER}"
  log "ArgoCD Application 回滚 → ${app_name}"

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -n "$REVISION" ]]; then
      echo "[dry-run] ${ARGOCD} app rollback ${app_name} ${REVISION}"
    else
      echo "[dry-run] ${ARGOCD} app rollback ${app_name}"
    fi
    return 0
  fi

  if ! ${ARGOCD} app get "${app_name}" &>/dev/null; then
    log "WARN: ArgoCD app ${app_name} 不存在，跳过"
    return 1
  fi

  if [[ -n "$REVISION" ]]; then
    run_cmd "${ARGOCD} app rollback ${app_name} ${REVISION}"
  else
    run_cmd "${ARGOCD} app rollback ${app_name}"
  fi

  run_cmd "${ARGOCD} app wait ${app_name} --health --timeout 180"
  return 0
}

rollback_deployment() {
  local deploy_name="${SERVICE}"
  if ! ${KUBECTL} get deployment "${deploy_name}" -n "${NAMESPACE}" &>/dev/null; then
    log "WARN: Deployment ${deploy_name} 不存在"
    return 1
  fi

  log "kubectl rollout undo → Deployment/${deploy_name}"
  run_cmd "${KUBECTL} rollout undo deployment/${deploy_name} -n ${NAMESPACE}"

  if [[ "$DRY_RUN" == false ]]; then
    run_cmd "${KUBECTL} rollout status deployment/${deploy_name} -n ${NAMESPACE} --timeout=180s"
  fi
  return 0
}

restore_gateway() {
  local route_name="${ROUTE_NAME:-${SERVICE}-api}"
  local gateway_ns="${GATEWAY_NS:-gateway}"

  log "恢复 APISIX canary 权重 → 0%（全量 stable）"

  local patch
  patch=$(cat <<EOF
{
  "metadata": {
    "annotations": {
      "baobao.io/canary-weight": "0",
      "baobao.io/rollback-at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
  },
  "spec": {
    "http": [{
      "backends": [
        {"serviceName": "${SERVICE}-canary", "servicePort": 80, "weight": 0},
        {"serviceName": "${SERVICE}-stable", "servicePort": 80, "weight": 100}
      ]
    }]
  }
}
EOF
)

  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] ${KUBECTL} patch apisixroute ${route_name} -n ${gateway_ns}"
    return
  fi

  if ${KUBECTL} get apisixroute "${route_name}" -n "${gateway_ns}" &>/dev/null; then
    echo "${patch}" | ${KUBECTL} patch apisixroute "${route_name}" -n "${gateway_ns}" --type=merge -p "$(cat)"
    log "网关权重已恢复"
  else
    log "WARN: ApisixRoute ${route_name} 不存在，跳过网关恢复"
  fi
}

verify_rollback() {
  if [[ "$DRY_RUN" == true ]]; then
    return
  fi

  # 检查 Pod 是否回到 stable 镜像
  local current_image
  current_image=$(${KUBECTL} get pods -n "${NAMESPACE}" -l "app.kubernetes.io/name=${SERVICE}" \
    -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null || echo "unknown")
  log "当前 Pod 镜像: ${current_image}"

  # 快速健康检查
  if command -v curl >/dev/null 2>&1; then
    local host
    case "${CLUSTER}" in
      ack-cn) host="${GATEWAY_HOST_CN:-staging-api-cn.example.com}" ;;
      eks-os) host="${GATEWAY_HOST_OS:-staging-api-os.example.com}" ;;
      *) host="${GATEWAY_HOST:-staging-api-cn.example.com}" ;;
    esac
    local code
    code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 \
      "https://${host}/health" 2>/dev/null || echo "000")
    log "回滚后健康检查 → ${host}/health HTTP ${code}"
  fi
}

RESTORE_GATEWAY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --service) SERVICE="$2"; shift 2 ;;
    --cluster) CLUSTER="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --environment) ENVIRONMENT="$2"; shift 2 ;;
    --revision) REVISION="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --force-deployment) FORCE_DEPLOYMENT=true; shift ;;
    --restore-gateway) RESTORE_GATEWAY=true; shift ;;
    *) die "未知参数: $1" ;;
  esac
done

[[ -n "$SERVICE" ]] || die "缺少 --service"
[[ -n "$CLUSTER" ]] || die "缺少 --cluster"

case "$CLUSTER" in
  ack-cn|eks-os) ;;
  *) die "无效集群 ${CLUSTER}" ;;
esac

START_TS=$(date +%s)
log "开始回滚: service=${SERVICE} cluster=${CLUSTER} ns=${NAMESPACE} SLA=${ROLLBACK_SLA}s"

switch_context

ROLLED_BACK=false

if [[ "$FORCE_DEPLOYMENT" == true ]]; then
  rollback_deployment && ROLLED_BACK=true
else
  if rollback_rollout; then
    ROLLED_BACK=true
  elif rollback_argocd; then
    ROLLED_BACK=true
  elif rollback_deployment; then
    ROLLED_BACK=true
  fi
fi

[[ "$ROLLED_BACK" == true ]] || die "所有回滚路径均失败，请人工介入"

if [[ "$RESTORE_GATEWAY" == true ]]; then
  restore_gateway
fi

verify_rollback
check_sla "$START_TS"

log "回滚完成 ✓"
