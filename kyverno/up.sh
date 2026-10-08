#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=kyverno
CONTEXT="kind-${CLUSTER_NAME}"
KYVERNO_CHART_VERSION=3.9.1
POLICY_REPORTER_CHART_VERSION=3.11.0

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
helm repo add policy-reporter https://kyverno.github.io/policy-reporter >/dev/null 2>&1 || true
helm repo update kyverno policy-reporter >/dev/null

echo "==> Installing Kyverno"
helm upgrade --install kyverno kyverno/kyverno \
  --kube-context "${CONTEXT}" \
  --namespace kyverno --create-namespace \
  --version "${KYVERNO_CHART_VERSION}" \
  --values kyverno-values.yaml \
  --wait --timeout 5m

echo "==> Installing Policy Reporter"
helm upgrade --install policy-reporter policy-reporter/policy-reporter \
  --kube-context "${CONTEXT}" \
  --namespace policy-reporter --create-namespace \
  --version "${POLICY_REPORTER_CHART_VERSION}" \
  --values policy-reporter-values.yaml \
  --wait --timeout 5m
kubectl --context "${CONTEXT}" -n policy-reporter patch svc policy-reporter-ui --type json \
  -p '[{"op":"replace","path":"/spec/ports/0/nodePort","value":30082}]'

echo "==> Applying policies"
kubectl --context "${CONTEXT}" apply -f policies/
for kind in validatingpolicies mutatingpolicies generatingpolicies; do
  kubectl --context "${CONTEXT}" wait "${kind}.policies.kyverno.io" --all --for=condition=Ready --timeout=120s
done

echo "==> Deploying demo apps"
kubectl --context "${CONTEXT}" apply -f manifests/demo-apps.yaml -f manifests/exception.yaml
for d in good sloppy legacy; do
  kubectl --context "${CONTEXT}" -n demo rollout status "deploy/${d}" --timeout=180s
done

cat <<EOT

Done. Policy reports fill in within a minute or so.
  Policy Reporter UI: http://localhost:8082
  Reports:            kubectl --context ${CONTEXT} get policyreports -A
  Try a denied apply: kubectl --context ${CONTEXT} -n demo create deployment no-team --image=nginx:1.31.6-alpine
EOT
