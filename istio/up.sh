#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=istio
CONTEXT="kind-${CLUSTER_NAME}"
ISTIO_CHART_VERSION=1.30.5

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

helm repo add istio https://istio-release.storage.googleapis.com/charts >/dev/null 2>&1 || true
helm repo update istio >/dev/null

echo "==> Installing Istio base (CRDs)"
helm upgrade --install istio-base istio/base \
  --kube-context "${CONTEXT}" \
  --namespace istio-system --create-namespace \
  --version "${ISTIO_CHART_VERSION}" \
  --wait --timeout 5m

echo "==> Installing istiod"
helm upgrade --install istiod istio/istiod \
  --kube-context "${CONTEXT}" \
  --namespace istio-system \
  --version "${ISTIO_CHART_VERSION}" \
  --values istiod-values.yaml \
  --wait --timeout 5m

echo "==> Installing ingress gateway"
helm upgrade --install istio-ingress istio/gateway \
  --kube-context "${CONTEXT}" \
  --namespace istio-ingress --create-namespace \
  --version "${ISTIO_CHART_VERSION}" \
  --values gateway-values.yaml \
  --wait --timeout 5m

echo "==> Deploying demo app"
kubectl --context "${CONTEXT}" apply -f manifests/demo.yaml
for d in app-v1 app-v2; do
  kubectl --context "${CONTEXT}" -n demo rollout status "deploy/${d}" --timeout=180s
done

cat <<EOT

Done. Istio runs in sidecar mode; the demo namespace has injection enabled.
  demo app (90% v1 / 10% v2): http://localhost:30061
  Try it:        for i in \$(seq 20); do curl -s localhost:30061; done | sort | uniq -c
  Sidecars:      kubectl --context ${CONTEXT} -n demo get pods   (READY 2/2)
  istiod logs:   kubectl --context ${CONTEXT} -n istio-system logs deploy/istiod -f
EOT
