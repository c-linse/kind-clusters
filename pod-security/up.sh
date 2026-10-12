#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=pod-security
CONTEXT="kind-${CLUSTER_NAME}"

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

echo "==> Creating psa-* namespaces"
kubectl --context "${CONTEXT}" apply -f manifests/namespaces.yaml

cat <<EOT

Done. Pod Security Admission is built in; nothing else is installed.
  Labels:        kubectl --context ${CONTEXT} get ns -L pod-security.kubernetes.io/enforce,pod-security.kubernetes.io/warn
  Denied:        kubectl --context ${CONTEXT} -n psa-restricted apply -f manifests/pods/baseline.yaml
  Allowed+warn:  kubectl --context ${CONTEXT} -n psa-baseline apply -f manifests/pods/baseline.yaml
EOT
