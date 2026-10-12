# istio

Minimal single-node kind cluster with [Istio](https://istio.io/) in sidecar mode, installed from the Helm charts (`istio/base`, `istio/istiod`, `istio/gateway`). No `istioctl`, no Kiali, no Prometheus. kind has no LoadBalancer, so the ingress gateway is a NodePort Service on http://localhost:30061.

`manifests/demo.yaml` adds a `demo` namespace with `istio-injection=enabled`, two versions of `hashicorp/http-echo` (`app-v1`, `app-v2`) behind one Service `app`, and an Istio `Gateway`, `DestinationRule` (subsets v1/v2) and `VirtualService` that splits traffic 90/10.

## Prerequisites

`kind`, `kubectl`, `helm`, and docker or podman. See [../prometheus-operator/README.md](../prometheus-operator/README.md#prerequisites) for the inotify sysctl. Without it, a second kind cluster fails at "Preparing nodes".

## Usage

```sh
./up.sh
./down.sh
```

```sh
alias k='kubectl --context kind-istio -n demo'

k get pods                                                   # READY 2/2: app + istio-proxy
for i in $(seq 20); do curl -s localhost:30061; done | sort | uniq -c   # ~18 v1, ~2 v2
```

## Traffic shifting

Change the weights in the VirtualService, e.g. 50/50, then all to v2:

```sh
k patch virtualservice app --type json -p '[
  {"op":"replace","path":"/spec/http/0/route/0/weight","value":50},
  {"op":"replace","path":"/spec/http/0/route/1/weight","value":50}]'
```

Header-based routing: add a match rule before the weighted route so `curl -H 'x-version: v2' localhost:30061` always hits v2:

```sh
k patch virtualservice app --type json -p '[{"op":"add","path":"/spec/http/0","value":
  {"match":[{"headers":{"x-version":{"exact":"v2"}}}],
   "route":[{"destination":{"host":"app.demo.svc.cluster.local","subset":"v2"}}]}}]'
```

## mTLS

Sidecars use mTLS between each other automatically (PERMISSIVE). To reject plaintext from pods outside the mesh:

```sh
k apply -f - <<YAML
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT
YAML

# A pod without a sidecar now fails, the gateway (in the mesh) still works
kubectl --context kind-istio run plain --rm -it --image=curlimages/curl:8.16.0 --restart=Never -- curl -s --max-time 3 http://app.demo
curl -s localhost:30061
```

Reset the scenario:

```sh
kubectl --context kind-istio delete ns demo && kubectl --context kind-istio apply -f manifests/demo.yaml
```
