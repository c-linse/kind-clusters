#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=gateway-api
CONTEXT="kind-${CLUSTER_NAME}"
ENVOY_GATEWAY_VERSION=v1.9.2

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

# The Gateway API CRDs are too large for helm install, so render the CRD chart
# and apply it server-side. It bundles the Gateway API version this Envoy
# Gateway release is tested against, here the experimental channel (TLSRoute,
# TCPRoute, UDPRoute, ListenerSet, XBackendTrafficPolicy, ...).
# helm prints "Pulled:" and "Digest:" for OCI charts to stdout; drop them.
echo "==> Installing Gateway API (experimental) and Envoy Gateway CRDs"
helm template eg oci://docker.io/envoyproxy/gateway-crds-helm \
  --version "${ENVOY_GATEWAY_VERSION}" \
  --set crds.gatewayAPI.enabled=true \
  --set crds.gatewayAPI.channel=experimental \
  --set crds.envoyGateway.enabled=true \
  | grep -v -e '^Pulled: ' -e '^Digest: ' \
  | kubectl --context "${CONTEXT}" apply --server-side -f -

echo "==> Installing Envoy Gateway ${ENVOY_GATEWAY_VERSION}"
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --kube-context "${CONTEXT}" \
  --namespace envoy-gateway-system --create-namespace \
  --version "${ENVOY_GATEWAY_VERSION}" \
  --set crds.enabled=false \
  --wait --timeout 5m

echo "==> Deploying demo app and Gateway"
kubectl --context "${CONTEXT}" apply -f manifests/demo.yaml
for d in app-v1 app-v2; do
  kubectl --context "${CONTEXT}" -n demo rollout status "deploy/${d}" --timeout=180s
done
kubectl --context "${CONTEXT}" -n demo wait gateway/demo --for=condition=Programmed --timeout=180s

cat <<EOT

Done. Envoy Gateway ${ENVOY_GATEWAY_VERSION} with the experimental Gateway API CRDs.
Gateway demo/demo listens on http://localhost:8085 and routes to app-v1.
  Try it:        curl localhost:8085
  Traffic split: kubectl --context ${CONTEXT} apply -f manifests/split.yaml
  Status:        kubectl --context ${CONTEXT} -n demo get gateway,httproute
  Controller:    kubectl --context ${CONTEXT} -n envoy-gateway-system logs deploy/envoy-gateway -f
EOT
