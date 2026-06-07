#!/usr/bin/env bash
# ENV-06 · 验证 staging outbound Mock 可达性（本地 docker-compose 或 K8s）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODE="local"
K8S_NAMESPACE="staging"
K8S_RELEASE="third-party-mocks"
TIMEOUT=5

usage() {
  cat <<'EOF'
用法: verify-outbound.sh [--local | --k8s] [--namespace NS] [--timeout SEC]

  --local   检查宿主机 localhost:1808x（默认，需 docker compose up）
  --k8s     检查集群内 mock Service / Pod（需 kubectl + 已部署 third-party-mocks）
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local) MODE="local"; shift ;;
    --k8s) MODE="k8s"; shift ;;
    -n|--namespace) K8S_NAMESPACE="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
done

PASS=0
FAIL=0

pass() { echo "[PASS] $*"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $*" >&2; FAIL=$((FAIL + 1)); }

curl_health() {
  local url="$1"
  local label="$2"
  local code
  code="$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout "${TIMEOUT}" "${url}" 2>/dev/null || echo "000")"
  if [[ "${code}" == "200" ]]; then
    pass "${label} (${url})"
  else
    fail "${label} (${url}) HTTP ${code}"
  fi
}

# mock-api 用 /health；WireMock 用 /__admin/health
LOCAL_MOCKS=(
  "mock-api|http://localhost:18080/health"
  "mock-iap|http://localhost:18081/__admin/health"
  "mock-wechat|http://localhost:18082/__admin/health"
  "mock-ad|http://localhost:18083/__admin/health"
  "mock-audit|http://localhost:18084/__admin/health"
  "mock-ai|http://localhost:18085/__admin/health"
)

verify_local() {
  echo ">>> 本地 Mock 健康检查（docker compose）"
  for entry in "${LOCAL_MOCKS[@]}"; do
    name="${entry%%|*}"
    url="${entry#*|}"
    curl_health "${url}" "${name}"
  done

  echo ">>> 抽样 outbound 路径"
  curl_health "http://localhost:18081/verifyReceipt" "mock-iap POST /verifyReceipt (GET probe)" || true
  # WireMock 对 GET 未映射路径可能 404，仅检查 mock-wechat 根管理端点
  curl_health "http://localhost:18082/__admin/mappings" "mock-wechat mappings" || true
}

verify_k8s() {
  if ! command -v kubectl >/dev/null 2>&1; then
    fail "kubectl 未安装"
    return
  fi

  echo ">>> K8s Pod 就绪 (${K8S_NAMESPACE})"
  local mocks=(mock-iap mock-wechat mock-ad mock-audit mock-ai)
  for m in "${mocks[@]}"; do
    local ready
    ready="$(kubectl get pods -n "${K8S_NAMESPACE}" -l "app.kubernetes.io/name=${m},app.kubernetes.io/instance=${K8S_RELEASE}" \
      -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")"
    if [[ "${ready}" == "True" ]]; then
      pass "pod ${m} Ready"
    else
      fail "pod ${m} not Ready (${ready:-missing})"
    fi
  done

  echo ">>> K8s Service 存在"
  for m in "${mocks[@]}"; do
    if kubectl get svc "${m}" -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then
      pass "svc ${m}"
    else
      fail "svc ${m} missing"
    fi
  done

  echo ">>> 集群内 port-forward 抽样（可选，需 running pod）"
  local pod
  pod="$(kubectl get pods -n "${K8S_NAMESPACE}" -l "app.kubernetes.io/name=mock-iap,app.kubernetes.io/instance=${K8S_RELEASE}" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")"
  if [[ -n "${pod}" ]]; then
    kubectl port-forward -n "${K8S_NAMESPACE}" "pod/${pod}" 18081:8080 >/dev/null 2>&1 &
    local pf_pid=$!
    sleep 2
    curl_health "http://127.0.0.1:18081/__admin/health" "mock-iap port-forward" || true
    kill "${pf_pid}" 2>/dev/null || true
    wait "${pf_pid}" 2>/dev/null || true
  else
    fail "mock-iap pod 未找到，跳过 port-forward 抽样"
  fi
}

verify_helm_chart() {
  echo ">>> Helm chart 静态检查"
  local chart="${ROOT}/infra/k8s/charts/third-party-mocks"
  if [[ ! -d "${chart}" ]]; then
    fail "chart 目录不存在"
    return
  fi
  if [[ ! -d "${chart}/bundled-mappings/iap" ]]; then
    fail "bundled-mappings 未同步，运行: ./infra/staging/scripts/sync-mock-mappings.sh"
    return
  fi
  pass "bundled-mappings 已存在"
  if command -v helm >/dev/null 2>&1; then
    (cd "${chart}" && helm dependency update >/dev/null 2>&1 && helm lint . >/dev/null 2>&1) && pass "helm lint third-party-mocks" || fail "helm lint third-party-mocks"
  else
    echo "[SKIP] helm 未安装"
  fi
}

case "${MODE}" in
  local) verify_local ;;
  k8s) verify_k8s ;;
esac
verify_helm_chart

echo "---"
echo "结果: PASS=${PASS} FAIL=${FAIL}"
if [[ "${FAIL}" -gt 0 ]]; then
  echo "提示: 本地模式请先执行 cd tests/mocks && docker compose up -d"
  exit 1
fi
exit 0
