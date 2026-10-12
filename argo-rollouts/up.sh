#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=argo-rollouts
CONTEXT="kind-${CLUSTER_NAME}"
ROLLOUTS_CHART_VERSION=2.43.6

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null

echo "==> Installing Argo Rollouts"
helm upgrade --install argo-rollouts argo/argo-rollouts \
  --kube-context "${CONTEXT}" \
  --namespace argo-rollouts --create-namespace \
  --version "${ROLLOUTS_CHART_VERSION}" \
  --values argo-rollouts-values.yaml \
  --wait --timeout 5m

echo "==> Deploying demo app"
kubectl --context "${CONTEXT}" apply -f manifests/demo.yaml
kubectl --context "${CONTEXT}" -n demo wait rollout/app --for=condition=Healthy --timeout=180s

echo "==> Deploying blue-green demo app"
kubectl --context "${CONTEXT}" apply -f manifests/bluegreen.yaml
kubectl --context "${CONTEXT}" -n bluegreen wait rollout/bg --for=condition=Healthy --timeout=180s

cat <<EOT

Done. Argo Rollouts runs without traffic routing; canary weight = replica ratio.
  Dashboard:        http://localhost:3110
  demo app:         http://localhost:30051
  blue-green:       http://localhost:30052 (active), http://localhost:30053 (preview)
  Watch rollout:    kubectl argo rollouts --context ${CONTEXT} -n demo get rollout app -w
  Start a rollout:  kubectl --context ${CONTEXT} -n demo patch rollout app --type json \\
                      -p '[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/value","value":"1.0.1"}]'
  Promote:          kubectl argo rollouts --context ${CONTEXT} -n demo promote app
  Controller logs:  kubectl --context ${CONTEXT} -n argo-rollouts logs deploy/argo-rollouts -f
EOT
