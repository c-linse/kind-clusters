#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=flagger
CONTEXT="kind-${CLUSTER_NAME}"
FLAGGER_CHART_VERSION=1.45.0

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

helm repo add flagger https://flagger.app >/dev/null 2>&1 || true
helm repo update flagger >/dev/null

echo "==> Installing Flagger"
helm upgrade --install flagger flagger/flagger \
  --kube-context "${CONTEXT}" \
  --namespace flagger-system --create-namespace \
  --version "${FLAGGER_CHART_VERSION}" \
  --values flagger-values.yaml \
  --wait --timeout 5m

echo "==> Deploying malawi apps"
kubectl --context "${CONTEXT}" apply -f manifests/malawi.yaml
for d in app1 app2; do
  kubectl --context "${CONTEXT}" -n malawi rollout status "deploy/${d}" --timeout=180s
done

cat <<EOT

Done. Flagger runs with meshProvider=kubernetes; no Canaries exist yet.
  Create one:    kubectl --context ${CONTEXT} -n malawi apply -f <your-canary.yaml>
  Canary status: kubectl --context ${CONTEXT} -n malawi get canary -w
  Flagger logs:  kubectl --context ${CONTEXT} -n flagger-system logs deploy/flagger -f
  malawi apps:   http://localhost:30041  http://localhost:30042  (served once a Canary is Initialized)
EOT
