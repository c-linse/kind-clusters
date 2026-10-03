#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=prometheus-operator
CONTEXT="kind-${CLUSTER_NAME}"
CHART_VERSION=91.9.0

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

echo "==> Installing kube-prometheus-stack"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update prometheus-community >/dev/null
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --kube-context "${CONTEXT}" \
  --namespace monitoring --create-namespace \
  --version "${CHART_VERSION}" \
  --values values.yaml \
  --wait --timeout 10m

cat <<EOF

Done.
  Grafana:      http://localhost:3000  (admin / admin)
  Prometheus:   http://localhost:9090
  Alertmanager: http://localhost:9093
EOF
