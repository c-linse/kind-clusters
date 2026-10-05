#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=opentofu
CONTEXT="kind-${CLUSTER_NAME}"

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

echo "==> Applying OpenTofu project"
tofu -chdir=tofu init -input=false
tofu -chdir=tofu apply -input=false -auto-approve -var "kube_context=${CONTEXT}"

cat <<EOF

Done.
  Demo app: http://localhost:8080

Try it:
  kubectl --context ${CONTEXT} -n demo get deploy,pods,svc
  tofu -chdir=tofu apply -var replicas=3
EOF
