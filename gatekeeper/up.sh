#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=gatekeeper
CONTEXT="kind-${CLUSTER_NAME}"
GATEKEEPER_CHART_VERSION=3.23.1

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts >/dev/null 2>&1 || true
helm repo update gatekeeper >/dev/null

echo "==> Installing Gatekeeper"
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --kube-context "${CONTEXT}" \
  --namespace gatekeeper-system --create-namespace \
  --version "${GATEKEEPER_CHART_VERSION}" \
  --values gatekeeper-values.yaml \
  --wait --timeout 5m

# Each ConstraintTemplate creates a constraint CRD (kind K8sRequiredLabels,
# ...). Constraints can only be applied once that CRD exists.
echo "==> Applying ConstraintTemplates"
kubectl --context "${CONTEXT}" apply -f policies/templates/
kubectl --context "${CONTEXT}" wait constrainttemplates --all \
  --for=jsonpath='{.status.created}'=true --timeout=120s

echo "==> Applying constraints and mutations"
kubectl --context "${CONTEXT}" apply -f policies/constraints/ -f policies/mutations/
# The webhook only enforces a constraint once the controller has picked it up.
for c in k8srequiredlabels k8sdisallowedtags k8srequiredresources; do
  kubectl --context "${CONTEXT}" wait "${c}" --all \
    --for=jsonpath='{.status.byPod[0].enforced}'=true --timeout=120s
done
kubectl --context "${CONTEXT}" wait assignmetadata --all \
  --for=jsonpath='{.status.byPod[0].enforced}'=true --timeout=120s

echo "==> Deploying demo apps"
kubectl --context "${CONTEXT}" apply -f manifests/demo-apps.yaml
for d in good sloppy; do
  kubectl --context "${CONTEXT}" -n demo rollout status "deploy/${d}" --timeout=180s
done

cat <<EOT

Done. Audit runs every 20s and fills .status.violations on each constraint.
  Constraints:        kubectl --context ${CONTEXT} get constraints
  Audit results:      kubectl --context ${CONTEXT} get k8srequiredresources require-resources -o yaml
  Try a denied apply: kubectl --context ${CONTEXT} -n demo create deployment no-team --image=nginx:1.31.6-alpine
EOT
