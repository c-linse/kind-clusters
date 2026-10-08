#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=opencost
CONTEXT="kind-${CLUSTER_NAME}"
PROMETHEUS_CHART_VERSION=29.36.0
OPENCOST_CHART_VERSION=2.5.32

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add opencost https://opencost.github.io/opencost-helm-chart >/dev/null 2>&1 || true
helm repo update prometheus-community opencost >/dev/null

echo "==> Installing Prometheus"
helm upgrade --install prometheus prometheus-community/prometheus \
  --kube-context "${CONTEXT}" \
  --namespace prometheus-system --create-namespace \
  --version "${PROMETHEUS_CHART_VERSION}" \
  --values prometheus-values.yaml \
  --wait --timeout 5m

echo "==> Installing OpenCost"
helm upgrade --install opencost opencost/opencost \
  --kube-context "${CONTEXT}" \
  --namespace opencost --create-namespace \
  --version "${OPENCOST_CHART_VERSION}" \
  --values opencost-values.yaml \
  --wait --timeout 5m

echo "==> Deploying demo apps"
kubectl --context "${CONTEXT}" apply -f manifests/demo-apps.yaml
for d in team-a/web team-a/worker team-b/api team-b/batch; do
  kubectl --context "${CONTEXT}" -n "${d%/*}" rollout status "deploy/${d#*/}" --timeout=180s
done

cat <<EOT

Done. Cost data needs a few minutes of Prometheus history before it shows up.
  OpenCost UI:  http://localhost:9095
  OpenCost API: curl -s 'http://localhost:9095/model/allocation?window=1h&aggregate=namespace' | jq
  Prometheus:   http://localhost:9096
EOT
