#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=argo-workflows
CONTEXT="kind-${CLUSTER_NAME}"
ARGO_CHART_VERSION=2.0.11

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

echo "==> Deploying SeaweedFS"
kubectl --context "${CONTEXT}" apply -f seaweedfs.yaml
kubectl --context "${CONTEXT}" -n seaweedfs rollout status deploy/seaweedfs --timeout=180s
kubectl --context "${CONTEXT}" -n seaweedfs wait --for=condition=complete job/create-argo-bucket --timeout=180s

echo "==> Installing Argo Workflows"
kubectl --context "${CONTEXT}" create namespace argo --dry-run=client -o yaml | kubectl --context "${CONTEXT}" apply -f -
kubectl --context "${CONTEXT}" apply -f argo-s3-secret.yaml
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null
helm upgrade --install argo-workflows argo/argo-workflows \
  --kube-context "${CONTEXT}" \
  --namespace argo \
  --version "${ARGO_CHART_VERSION}" \
  --values argo-values.yaml \
  --wait --timeout 5m

cat <<EOF

Done.
  Argo UI:     http://localhost:2746
  SeaweedFS S3: http://localhost:8333  (access key: argo / secret: argo-secret-key)

Try it:
  kubectl --context ${CONTEXT} create -f example-workflow.yaml
  kubectl --context ${CONTEXT} -n argo get workflows -w
EOF
