#!/usr/bin/env bash
# ENV-03 · Staging 健康检查与冒烟验收
#
# 用法:
#   ./tests/staging/smoke-staging.sh --cluster ack-cn
#   ./tests/staging/smoke-staging.sh --cluster ack-cn --resolve 10.0.0.1
#   ./tests/staging/smoke-staging.sh --k8s-only
#   ./tests/staging/smoke-staging.sh --full-smoke
#
# 环境变量:
#   STAGING_API_CN / STAGING_API_OS   API 基址
#   STAGING_RESOLVE                   curl --resolve（host:443:ip）
#   STAGING_NAMESPACE                 K8s 命名空间（默认 staging）

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLUSTER=""
NAMESPACE="${STAGING_NAMESPACE:-staging}"
RESOLVE="${STAGING_RESOLVE:-}"
K8S_ONLY=false
FULL_SMOKE=false
STATIC_ONLY=false
INSECURE="${INSECURE:-0}"

SERVICES=(
  auth-family-svc
  media-svc
  feed-svc
  audit-svc
  ai-dispatch-svc
  credit-sub-ad-svc
)

usage() {
  cat <<'EOF'
用法: smoke-staging.sh [选项]

选项:
  --cluster ack-cn|eks-os   选择区域（决定默认 API 域名）
  --namespace NS            K8s 命名空间（默认 staging）
  --resolve IP              APISIX LB IP（传给 curl --resolve）
  --k8s-only                仅检查集群内 Pod/Service
  --static-only             仅 manifest/脚本静态检查（无需 VPN）
  --full-smoke              额外运行 tests/smoke/smoke.sh 端到端
  --insecure                跳过 TLS 校验
  -h, --help                显示帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) CLUSTER="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --resolve) RESOLVE="$2"; shift 2 ;;
    --k8s-only) K8S_ONLY=true; shift ;;
    --static-only) STATIC_ONLY=true; shift ;;
    --full-smoke) FULL_SMOKE=true; shift ;;
    --insecure) INSECURE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
done

PASS=0
FAIL=0

pass() { echo "[PASS] $*"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $*" >&2; FAIL=$((FAIL + 1)); }

api_host_for_cluster() {
  case "$1" in
    ack-cn) echo "${STAGING_API_CN:-https://staging-api-cn.example.com}" ;;
    eks-os) echo "${STAGING_API_OS:-https://staging-api-os.example.com}" ;;
    *) echo "" ;;
  esac
}

resolve_host_from_url() {
  local url="$1"
  local host
  host="$(echo "${url}" | sed -E 's|^https?://([^/:]+).*|\1|')"
  echo "${host}"
}

check_gateway_health() {
  local base_url="$1"
  local host
  host="$(resolve_host_from_url "${base_url}")"
  local -a curl_opts=(-sS -o /dev/null -w "%{http_code}")
  [[ "${INSECURE}" == "1" ]] && curl_opts+=(-k)
  if [[ -n "${RESOLVE}" ]]; then
    curl_opts+=(--resolve "${host}:443:${RESOLVE}")
  fi
  local code
  code="$(curl "${curl_opts[@]}" \
    -H "X-Region: cn" \
    -H "X-App-Version: 1.0.0-staging" \
    -H "X-Device-Id: qa-device-001" \
    "${base_url%/}/health" 2>/dev/null || echo "000")"
  if [[ "${code}" == "200" ]]; then
    pass "GET ${base_url%/}/health → HTTP 200"
  else
    fail "GET ${base_url%/}/health → HTTP ${code} (期望 200，需 VPN/INFRA 或 --resolve)"
  fi
}

check_k8s() {
  if ! command -v kubectl >/dev/null 2>&1; then
    fail "kubectl 未安装"
    return
  fi
  echo ">>> K8s Pod Ready (${NAMESPACE})"
  for svc in "${SERVICES[@]}"; do
    local ready
    ready="$(kubectl get pods -n "${NAMESPACE}" \
      -l "app.kubernetes.io/name=${svc},app.kubernetes.io/instance=baobao-staging" \
      -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")"
    if [[ "${ready}" == "True" ]]; then
      pass "pod ${svc} Ready"
    else
      # 单服务 release 模式（非 umbrella）
      ready="$(kubectl get pods -n "${NAMESPACE}" \
        -l "app.kubernetes.io/name=${svc}" \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")"
      if [[ "${ready}" == "True" ]]; then
        pass "pod ${svc} Ready"
      else
        fail "pod ${svc} not Ready (${ready:-missing})"
      fi
    fi
  done

  echo ">>> K8s Service 存在"
  for svc in "${SERVICES[@]}"; do
    if kubectl get svc "${svc}" -n "${NAMESPACE}" >/dev/null 2>&1; then
      pass "svc ${svc}"
    else
      fail "svc ${svc} missing"
    fi
  done

  echo ">>> 集群内 /health 抽样（port-forward auth-family-svc）"
  local pod
  pod="$(kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/name=auth-family-svc" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")"
  if [[ -n "${pod}" ]]; then
    kubectl port-forward -n "${NAMESPACE}" "pod/${pod}" 18001:8001 >/dev/null 2>&1 &
    local pf_pid=$!
    sleep 2
    local code
    code="$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 5 http://127.0.0.1:18001/health 2>/dev/null || echo "000")"
    if [[ "${code}" == "200" ]]; then
      pass "auth-family-svc in-cluster /health"
    else
      fail "auth-family-svc in-cluster /health HTTP ${code}"
    fi
    kill "${pf_pid}" 2>/dev/null || true
    wait "${pf_pid}" 2>/dev/null || true
  else
    fail "auth-family-svc pod 未找到，跳过 port-forward"
  fi
}

check_helm_static() {
  echo ">>> Helm chart / manifest 静态检查"
  local -a required=(
    "${ROOT}/infra/k8s/charts/microservice/Chart.yaml"
    "${ROOT}/infra/k8s/charts/baobao-staging/Chart.yaml"
    "${ROOT}/infra/k8s/clusters/ack-cn/staging-services-values.yaml"
    "${ROOT}/infra/k8s/clusters/eks-os/staging-services-values.yaml"
    "${ROOT}/infra/k8s/argocd/applications/baobao-staging-ack-cn.yaml"
    "${ROOT}/infra/gateway/routes/staging-api-health.yaml"
    "${ROOT}/infra/staging/scripts/deploy-staging.sh"
  )
  for f in "${required[@]}"; do
    [[ -f "${f}" ]] && pass "manifest ${f##*/}" || fail "missing ${f}"
  done

  local chart="${ROOT}/infra/k8s/charts/baobao-staging"
  if command -v helm >/dev/null 2>&1; then
    (cd "${chart}" && helm dependency update >/dev/null 2>&1 && helm lint . >/dev/null 2>&1) \
      && pass "helm lint baobao-staging" || fail "helm lint baobao-staging"
    (cd "${chart}" && helm template baobao-staging . -n staging \
      -f "${ROOT}/infra/k8s/clusters/ack-cn/cluster-values.yaml" \
      -f "${ROOT}/infra/k8s/clusters/ack-cn/staging-services-values.yaml" \
      >/dev/null 2>&1) && pass "helm template baobao-staging" || fail "helm template baobao-staging"
  else
    echo "[SKIP] helm 未安装，跳过 lint/template"
  fi
  [[ -x "${ROOT}/infra/staging/scripts/deploy-staging.sh" ]] \
    && pass "deploy-staging.sh 可执行" || fail "deploy-staging.sh 不可执行"
}

run_full_smoke() {
  local base_url="$1"
  echo ">>> 端到端 smoke.sh"
  export BASE_URL="${base_url}"
  export SMOKE_PHONE="${SMOKE_PHONE:-13800138001}"
  export SMOKE_CODE="${SMOKE_CODE:-123456}"
  if [[ -n "${RESOLVE}" ]]; then
    export STAGING_RESOLVE="${RESOLVE}"
  fi
  if (cd "${ROOT}/tests/smoke" && ./smoke.sh); then
    pass "smoke.sh 全绿"
  else
    fail "smoke.sh 失败"
  fi
}

main() {
  check_helm_static

  if [[ "${STATIC_ONLY}" != true && "${K8S_ONLY}" != true ]]; then
    local base_url=""
    if [[ -n "${CLUSTER}" ]]; then
      base_url="$(api_host_for_cluster "${CLUSTER}")"
    elif [[ -n "${STAGING_API_CN:-}" ]]; then
      base_url="${STAGING_API_CN}"
    else
      base_url="https://staging-api-cn.example.com"
    fi
    echo ">>> 网关健康检查 base=${base_url}"
    check_gateway_health "${base_url}"
  fi

  if [[ "${STATIC_ONLY}" != true ]] && command -v kubectl >/dev/null 2>&1; then
    check_k8s
  else
    echo "[SKIP] kubectl 未安装，跳过 K8s 检查"
  fi

  if [[ "${FULL_SMOKE}" == true ]]; then
    local smoke_url
    smoke_url="$(api_host_for_cluster "${CLUSTER:-ack-cn}")"
    run_full_smoke "${smoke_url}"
  fi

  echo "---"
  echo "结果: PASS=${PASS} FAIL=${FAIL}"
  if [[ "${FAIL}" -gt 0 ]]; then
    echo "提示: 集群未部署时网关检查失败属预期；先运行 infra/staging/scripts/deploy-staging.sh --cluster ${CLUSTER:-ack-cn}"
    exit 1
  fi
  exit 0
}

main "$@"
