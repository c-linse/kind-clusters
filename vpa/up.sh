#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=vpa
CONTEXT="kind-${CLUSTER_NAME}"
METRICS_SERVER_CHART_VERSION=3.14.0
VPA_CHART_VERSION=0.13.0

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null 2>&1 || true
helm repo add autoscaler https://kubernetes.github.io/autoscaler >/dev/null 2>&1 || true
helm repo update metrics-server autoscaler >/dev/null

echo "==> Installing metrics-server"
helm upgrade --install metrics-server metrics-server/metrics-server \
  --kube-context "${CONTEXT}" \
  --namespace kube-system \
  --version "${METRICS_SERVER_CHART_VERSION}" \
  --values metrics-server-values.yaml \
  --wait --timeout 5m

echo "==> Installing Vertical Pod Autoscaler"
helm upgrade --install vpa autoscaler/vertical-pod-autoscaler \
  --kube-context "${CONTEXT}" \
  --namespace vpa-system --create-namespace \
  --version "${VPA_CHART_VERSION}" \
  --values vpa-values.yaml \
  --wait --timeout 5m

echo "==> Deploying demo apps"
kubectl --context "${CONTEXT}" apply -f manifests/demo-apps.yaml
for d in hamster inplace oversized; do
  kubectl --context "${CONTEXT}" -n demo rollout status "deploy/${d}" --timeout=180s
done

cat <<EOT

Done. Recommendations appear after ~1-2 minutes of metrics.
  kubectl --context ${CONTEXT} -n demo get vpa
  kubectl --context ${CONTEXT} -n demo get pods \
      -o custom-columns='NAME:.metadata.name,CPU:.spec.containers[0].resources.requests.cpu,MEM:.spec.containers[0].resources.requests.memory,RESTARTS:.status.containerStatuses[0].restartCount'
EOT
