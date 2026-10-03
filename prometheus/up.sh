#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=prometheus
CONTEXT="kind-${CLUSTER_NAME}"
PROMETHEUS_CHART_VERSION=29.35.0
GRAFANA_CHART_VERSION=13.2.7

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add grafana-community https://grafana-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update prometheus-community grafana-community >/dev/null

echo "==> Installing Prometheus"
helm upgrade --install prometheus prometheus-community/prometheus \
  --kube-context "${CONTEXT}" \
  --namespace monitoring --create-namespace \
  --version "${PROMETHEUS_CHART_VERSION}" \
  --values prometheus-values.yaml \
  --wait --timeout 5m

echo "==> Installing Grafana"
helm upgrade --install grafana grafana-community/grafana \
  --kube-context "${CONTEXT}" \
  --namespace monitoring \
  --version "${GRAFANA_CHART_VERSION}" \
  --values grafana-values.yaml \
  --wait --timeout 5m

cat <<EOF

Done.
  Grafana:    http://localhost:3001  (admin / admin, Prometheus datasource preconfigured)
  Prometheus: http://localhost:9091
EOF
