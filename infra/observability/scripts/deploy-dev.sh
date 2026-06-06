#!/usr/bin/env bash
# T0.8 监控基线 — dev 一键部署
#
# 用法:
#   ./infra/observability/scripts/deploy-dev.sh
#   ./infra/observability/scripts/deploy-dev.sh --skip-helm   # 仅 apply K8s 清单
#
# 前置: kubectl 已指向 dev 集群；helm 3.x

set -euo pipefail

OBS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS="observability"
SKIP_HELM=false

for arg in "$@"; do
  case "$arg" in
    --skip-helm) SKIP_HELM=true ;;
  esac
done

log() { echo "[observability] $*"; }

log "apply namespace"
kubectl apply -f "${OBS}/k8s/namespace.yaml"

if [[ "${SKIP_HELM}" == "true" ]]; then
  log "skip helm (--skip-helm)"
else
  log "add helm repos"
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
  helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
  helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts 2>/dev/null || true
  helm repo update

  log "create prometheus additional scrape secret"
  kubectl create secret generic prometheus-additional-scrape-configs \
    -n "${NS}" \
    --from-file=prometheus-additional-scrape-configs.yaml="${OBS}/prometheus/scrape-configs/additional-scrape-configs.yaml" \
    --dry-run=client -o yaml | kubectl apply -f -

  log "install kube-prometheus-stack (release=prometheus)"
  helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    -n "${NS}" \
    -f "${OBS}/prometheus/values-dev.yaml" \
    --wait --timeout 10m

  log "install loki"
  helm upgrade --install loki grafana/loki \
    -n "${NS}" \
    -f "${OBS}/loki/values-dev.yaml" \
    --wait --timeout 10m

  log "install tempo"
  helm upgrade --install tempo grafana/tempo \
    -n "${NS}" \
    -f "${OBS}/tempo/values-dev.yaml" \
    --wait --timeout 10m

  log "install otel-collector"
  helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
    -n "${NS}" \
    -f "${OBS}/otel-collector/values-dev.yaml" \
    --wait --timeout 10m
fi

log "import grafana dashboards"
kubectl create configmap baobao-grafana-dashboards \
  -n "${NS}" \
  --from-file=baobao-api-overview.json="${OBS}/grafana/dashboards/api-overview.json" \
  --from-file=baobao-node-resources.json="${OBS}/grafana/dashboards/node-resources.json" \
  --dry-run=client -o yaml | \
  kubectl label --local -f - grafana_dashboard=1 -o yaml | \
  kubectl apply -f -

log "apply ServiceMonitors (hello + gateway)"
kubectl apply -f "${OBS}/prometheus/scrape-configs/hello-servicemonitor.yaml" || true
kubectl apply -f "${OBS}/prometheus/scrape-configs/gateway-servicemonitor.yaml" || true

log "apply hello OTEL integration example"
kubectl apply -f "${OBS}/examples/hello-observability.yaml" || true

log "done"
echo ""
echo "Grafana:  kubectl port-forward -n ${NS} svc/prometheus-grafana 3000:80"
echo "          用户 admin / 密码见 prometheus/values-dev.yaml (dev: changeme)"
echo "Prometheus: kubectl port-forward -n ${NS} svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo ""
echo "验收:"
echo "  1. hello Pod 设置 OTEL_EXPORTER_OTLP_ENDPOINT=otel-collector.${NS}.svc:4317"
echo "  2. curl hello → Grafana 看板 Baobao API Overview 出现 RPS"
echo "  3. Sentry smoke test — 见 sentry/README.md"
