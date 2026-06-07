#!/usr/bin/env bash
# ENV-03 · Staging 集群部署 auth/media/feed/ai-dispatch/credit 等微服务
#
# 用法:
#   ./infra/staging/scripts/deploy-staging.sh --cluster ack-cn
#   ./infra/staging/scripts/deploy-staging.sh --cluster eks-os --image-tag abc1234
#   ./infra/staging/scripts/deploy-staging.sh --cluster ack-cn --dry-run
#   ./infra/staging/scripts/deploy-staging.sh --cluster ack-cn --argocd
#
# 环境变量:
#   IMAGE_TAG          镜像 tag（默认 staging）
#   KUBECTL_CONTEXT    kubectl 上下文（默认与 --cluster 一致）
#   STAGING_NAMESPACE  命名空间（默认 staging）
#   SKIP_MOCKS         1 = 跳过 third-party-mocks
#   SKIP_ROUTES        1 = 跳过网关路由
#   SKIP_WAIT          1 = 不等待 Pod Ready

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CLUSTER=""
NAMESPACE="${STAGING_NAMESPACE:-staging}"
IMAGE_TAG="${IMAGE_TAG:-staging}"
DRY_RUN=false
USE_ARGOCD=false
SKIP_MOCKS="${SKIP_MOCKS:-0}"
SKIP_ROUTES="${SKIP_ROUTES:-0}"
SKIP_WAIT="${SKIP_WAIT:-0}"

SERVICES=(
  auth-family-svc
  media-svc
  feed-svc
  audit-svc
  ai-dispatch-svc
  credit-sub-ad-svc
  notification-svc
)

usage() {
  cat <<'EOF'
用法: deploy-staging.sh --cluster ack-cn|eks-os [选项]

选项:
  --cluster CLUSTER   目标集群（必填）
  --namespace NS      K8s 命名空间（默认 staging）
  --image-tag TAG     微服务镜像 tag（默认 staging 或 $IMAGE_TAG）
  --dry-run           helm template + kubectl apply --dry-run=client
  --argocd            通过 ArgoCD Application 同步（需 argocd CLI）
  --skip-mocks        跳过 third-party-mocks 部署
  --skip-routes       跳过 APISIX 路由 apply
  --skip-wait         不等待 Pod Ready
  -h, --help          显示帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) CLUSTER="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --image-tag) IMAGE_TAG="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --argocd) USE_ARGOCD=true; shift ;;
    --skip-mocks) SKIP_MOCKS=1; shift ;;
    --skip-routes) SKIP_ROUTES=1; shift ;;
    --skip-wait) SKIP_WAIT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "${CLUSTER}" ]]; then
  echo "错误: 必须指定 --cluster ack-cn 或 eks-os" >&2
  usage
  exit 1
fi

case "${CLUSTER}" in
  ack-cn|eks-os) ;;
  *) echo "错误: 不支持的集群 ${CLUSTER}" >&2; exit 1 ;;
esac

KUBECTL_CONTEXT="${KUBECTL_CONTEXT:-${CLUSTER}}"
HELM_RELEASE="baobao-staging"
CHART_DIR="${ROOT}/infra/k8s/charts/baobao-staging"
CLUSTER_VALUES="${ROOT}/infra/k8s/clusters/${CLUSTER}/cluster-values.yaml"
SERVICES_VALUES="${ROOT}/infra/k8s/clusters/${CLUSTER}/staging-services-values.yaml"
OUTBOUND_VALUES="${ROOT}/infra/staging/values/${CLUSTER}-outbound.yaml"
MOCKS_VALUES="${ROOT}/infra/k8s/clusters/${CLUSTER}/staging-third-party-mocks-values.yaml"

log() { printf '>>> [deploy-staging] %s\n' "$*"; }
die() { printf '>>> [deploy-staging] ERROR: %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

helm_upgrade() {
  local release="$1" chart="$2"
  shift 2
  local -a extra=("$@")
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN helm template ${release} ${chart}"
    helm template "${release}" "${chart}" -n "${NAMESPACE}" "${extra[@]}" >/dev/null
    return 0
  fi
  helm upgrade --install "${release}" "${chart}" -n "${NAMESPACE}" "${extra[@]}"
}

apply_routes() {
  local route_dir="${ROOT}/infra/gateway/routes"
  local -a routes=(
    "${route_dir}/staging-api-health.yaml"
    "${route_dir}/staging-auth-family-api.yaml"
  )
  for f in "${routes[@]}"; do
    [[ -f "${f}" ]] || die "路由文件不存在: ${f}"
    if [[ "${DRY_RUN}" == true ]]; then
      log "DRY-RUN kubectl apply -f ${f} -n ${NAMESPACE}"
      kubectl apply --dry-run=client -f "${f}" -n "${NAMESPACE}"
    else
      log "apply gateway route: ${f}"
      kubectl apply -f "${f}" -n "${NAMESPACE}"
    fi
  done
}

wait_pods() {
  log "等待微服务 Pod Ready（namespace=${NAMESPACE}）"
  for svc in "${SERVICES[@]}"; do
    if [[ "${DRY_RUN}" == true ]]; then
      log "DRY-RUN skip wait ${svc}"
      continue
    fi
    kubectl rollout status "deployment/${svc}" -n "${NAMESPACE}" --timeout=180s || \
      die "deployment/${svc} 未就绪"
  done
}

main() {
  require_cmd kubectl
  require_cmd helm

  log "cluster=${CLUSTER} namespace=${NAMESPACE} imageTag=${IMAGE_TAG} context=${KUBECTL_CONTEXT}"

  if [[ "${DRY_RUN}" != true ]]; then
    kubectl config use-context "${KUBECTL_CONTEXT}" >/dev/null 2>&1 || \
      die "kubectl 上下文 ${KUBECTL_CONTEXT} 不可用（需 VPN/INFRA kubeconfig）"
  fi

  # 1) 命名空间
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN kubectl apply namespaces"
    kubectl apply --dry-run=client -f "${ROOT}/infra/k8s/namespaces/namespaces.yaml"
  else
    kubectl apply -f "${ROOT}/infra/k8s/namespaces/namespaces.yaml"
    kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || \
      kubectl create namespace "${NAMESPACE}"
  fi

  # 2) 三方 Mock（ENV-06 依赖）
  if [[ "${SKIP_MOCKS}" != "1" ]]; then
    log "同步 WireMock mappings"
    if [[ "${DRY_RUN}" != true ]]; then
      "${ROOT}/infra/staging/scripts/sync-mock-mappings.sh"
    fi
    [[ -f "${MOCKS_VALUES}" ]] || die "缺少 ${MOCKS_VALUES}"
    helm dependency update "${ROOT}/infra/k8s/charts/third-party-mocks" >/dev/null
    helm_upgrade third-party-mocks "${ROOT}/infra/k8s/charts/third-party-mocks" \
      -f "${MOCKS_VALUES}"
  fi

  # 3) 微服务 umbrella chart
  [[ -d "${CHART_DIR}" ]] || die "chart 不存在: ${CHART_DIR}"
  [[ -f "${CLUSTER_VALUES}" ]] || die "缺少 ${CLUSTER_VALUES}"
  [[ -f "${SERVICES_VALUES}" ]] || die "缺少 ${SERVICES_VALUES}"

  helm dependency update "${CHART_DIR}" >/dev/null

  local -a helm_values=(
    -f "${CLUSTER_VALUES}"
    -f "${SERVICES_VALUES}"
  )
  [[ -f "${OUTBOUND_VALUES}" ]] && helm_values+=(-f "${OUTBOUND_VALUES}")

  for svc in "${SERVICES[@]}"; do
    local svc_values="${ROOT}/infra/staging/values/${svc}.yaml"
    [[ -f "${svc_values}" ]] && helm_values+=(-f "${svc_values}")
  done

  # 统一覆盖镜像 tag
  helm_values+=(--set-string "imageTag=${IMAGE_TAG}")
  for svc in "${SERVICES[@]}"; do
    helm_values+=(--set-string "${svc}.image.tag=${IMAGE_TAG}")
  done

  if [[ "${USE_ARGOCD}" == true ]]; then
    require_cmd argocd
    local app_name="baobao-staging-${CLUSTER}"
    log "ArgoCD sync ${app_name}"
    if [[ "${DRY_RUN}" != true ]]; then
      kubectl apply -f "${ROOT}/infra/k8s/argocd/applications/baobao-staging-${CLUSTER}.yaml"
      argocd app sync "${app_name}" --grpc-web
    fi
  else
    helm_upgrade "${HELM_RELEASE}" "${CHART_DIR}" "${helm_values[@]}"
  fi

  # 4) 网关路由
  if [[ "${SKIP_ROUTES}" != "1" ]]; then
    apply_routes
  fi

  # 5) 等待就绪
  if [[ "${SKIP_WAIT}" != "1" && "${DRY_RUN}" != true ]]; then
    wait_pods
  fi

  log "部署完成。健康检查: tests/staging/smoke-staging.sh --cluster ${CLUSTER}"
}

main "$@"
