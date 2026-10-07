#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=tekton
CONTEXT="kind-${CLUSTER_NAME}"
TEKTON_VERSION=v1.17.0

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

echo "==> Installing Tekton Pipelines ${TEKTON_VERSION}"
kubectl --context "${CONTEXT}" apply \
  -f "https://infra.tekton.dev/tekton-releases/pipeline/previous/${TEKTON_VERSION}/release.yaml"
for d in tekton-pipelines-controller tekton-pipelines-webhook; do
  kubectl --context "${CONTEXT}" -n tekton-pipelines rollout status "deploy/${d}" --timeout=300s
done
kubectl --context "${CONTEXT}" -n tekton-pipelines-resolvers rollout status deploy/tekton-pipelines-remote-resolvers --timeout=300s

echo "==> Applying example Tasks and Pipeline"
kubectl --context "${CONTEXT}" apply -f tasks/ -f pipelines/

cat <<EOF

Done.
Try it:
  tkn --context ${CONTEXT} task start hello --use-param-defaults --showlog
  tkn --context ${CONTEXT} pipeline start hello-pipeline --use-param-defaults \\
    --workspace name=shared,volumeClaimTemplateFile=runs/workspace-template.yaml --showlog
EOF
