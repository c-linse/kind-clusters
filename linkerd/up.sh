#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=linkerd
CONTEXT="kind-${CLUSTER_NAME}"
LINKERD_CHART_VERSION=2026.10.1
GATEWAY_API_VERSION=v1.6.3

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

# Linkerd identity needs a trust anchor and an issuer certificate. The Linkerd
# docs use the step CLI; openssl does the same. ECDSA P-256 keys, the issuer is
# an intermediate CA with CN identity.linkerd.cluster.local.
if [[ ! -f certs/issuer.crt ]]; then
  echo "==> Generating Linkerd identity certificates in certs/"
  mkdir -p certs
  openssl ecparam -name prime256v1 -genkey -noout -out certs/ca.key
  openssl req -x509 -new -key certs/ca.key -days 3650 -out certs/ca.crt \
    -subj "/CN=root.linkerd.cluster.local" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign"
  openssl ecparam -name prime256v1 -genkey -noout -out certs/issuer.key
  openssl req -new -key certs/issuer.key -out certs/issuer.csr \
    -subj "/CN=identity.linkerd.cluster.local"
  openssl x509 -req -in certs/issuer.csr -CA certs/ca.crt -CAkey certs/ca.key \
    -CAcreateserial -days 365 -out certs/issuer.crt \
    -extfile <(printf "basicConstraints=critical,CA:TRUE,pathlen:0\nkeyUsage=critical,keyCertSign,cRLSign\n")
fi

helm repo add linkerd-edge https://helm.linkerd.io/edge >/dev/null 2>&1 || true
helm repo update linkerd-edge >/dev/null

# Linkerd's policy controller needs the HTTPRoute/GRPCRoute CRDs.
# linkerd-crds no longer installs them by default (installGatewayAPI: false).
echo "==> Installing Gateway API CRDs ${GATEWAY_API_VERSION}"
kubectl --context "${CONTEXT}" apply --server-side \
  -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"

echo "==> Installing Linkerd CRDs"
helm upgrade --install linkerd-crds linkerd-edge/linkerd-crds \
  --kube-context "${CONTEXT}" \
  --namespace linkerd --create-namespace \
  --version "${LINKERD_CHART_VERSION}" \
  --wait --timeout 5m

echo "==> Installing Linkerd control plane"
helm upgrade --install linkerd-control-plane linkerd-edge/linkerd-control-plane \
  --kube-context "${CONTEXT}" \
  --namespace linkerd \
  --version "${LINKERD_CHART_VERSION}" \
  --values linkerd-values.yaml \
  --set-file identityTrustAnchorsPEM=certs/ca.crt \
  --set-file identity.issuer.tls.crtPEM=certs/issuer.crt \
  --set-file identity.issuer.tls.keyPEM=certs/issuer.key \
  --wait --timeout 5m

echo "==> Installing Linkerd Viz"
helm upgrade --install linkerd-viz linkerd-edge/linkerd-viz \
  --kube-context "${CONTEXT}" \
  --namespace linkerd-viz --create-namespace \
  --version "${LINKERD_CHART_VERSION}" \
  --values viz-values.yaml \
  --wait --timeout 5m
kubectl --context "${CONTEXT}" -n linkerd-viz patch svc web --type json -p '[
  {"op":"replace","path":"/spec/type","value":"NodePort"},
  {"op":"add","path":"/spec/ports/0/nodePort","value":30071}]'

echo "==> Deploying demo app"
kubectl --context "${CONTEXT}" apply -f manifests/demo.yaml
for d in app-v1 app-v2 client; do
  kubectl --context "${CONTEXT}" -n demo rollout status "deploy/${d}" --timeout=180s
done

cat <<EOT

Done. Linkerd (edge) with Viz; the demo namespace is meshed and the client
pod sends ~2 req/s to http://app (v1 only until you apply manifests/split.yaml).
  Viz dashboard:  http://localhost:8084
  Client output:  kubectl --context ${CONTEXT} -n demo logs deploy/client -f
  Traffic split:  kubectl --context ${CONTEXT} apply -f manifests/split.yaml
  Proxies:        kubectl --context ${CONTEXT} -n demo get pods   (READY 2/2)
EOT
