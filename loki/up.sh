#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=loki
CONTEXT="kind-${CLUSTER_NAME}"
LOKI_CHART_VERSION=18.13.8
ALLOY_CHART_VERSION=1.13.0
GRAFANA_CHART_VERSION=13.3.1

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add grafana-community https://grafana-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update grafana grafana-community >/dev/null

echo "==> Installing Loki"
helm upgrade --install loki grafana-community/loki \
  --kube-context "${CONTEXT}" \
  --namespace loki --create-namespace \
  --version "${LOKI_CHART_VERSION}" \
  --values loki-values.yaml \
  --wait --timeout 5m

echo "==> Installing Alloy (log collector)"
helm upgrade --install alloy grafana/alloy \
  --kube-context "${CONTEXT}" \
  --namespace logging --create-namespace \
  --version "${ALLOY_CHART_VERSION}" \
  --values alloy-values.yaml \
  --wait --timeout 5m

echo "==> Installing Grafana"
helm upgrade --install grafana grafana-community/grafana \
  --kube-context "${CONTEXT}" \
  --namespace monitoring --create-namespace \
  --version "${GRAFANA_CHART_VERSION}" \
  --values grafana-values.yaml \
  --wait --timeout 5m

echo "==> Deploying demo apps (log generators)"
kubectl --context "${CONTEXT}" apply -f manifests/demo-apps.yaml
for d in flog-json flog-apache orders; do
  kubectl --context "${CONTEXT}" -n demo rollout status "deploy/${d}" --timeout=180s
done

cat <<EOT

Done.
  Grafana: http://localhost:3002  (admin / admin, Loki datasource preconfigured)
  Loki:    http://localhost:3100  (no auth, e.g. curl localhost:3100/loki/api/v1/labels)
EOT
