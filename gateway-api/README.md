# gateway-api

Minimal single-node kind cluster for trying out the [Gateway API](https://gateway-api.sigs.k8s.io/), with [Envoy Gateway](https://gateway.envoyproxy.io/) as the implementation. Both charts come from `oci://docker.io/envoyproxy`: `gateway-crds-helm` for the CRDs and `gateway-helm` for the controller.

`up.sh` installs the **experimental** channel of the Gateway API CRDs that ship with Envoy Gateway (v1.6.1 for Envoy Gateway v1.9.2). Besides the standard resources you get `TLSRoute`, `TCPRoute`, `UDPRoute`, `ListenerSet`, `XBackendTrafficPolicy` and `XMesh`, plus the experimental fields on the standard resources. The CRDs are rendered with `helm template` and applied server-side because they are too large for `helm install`.

`manifests/demo.yaml` adds:

- a `GatewayClass` `eg` (the chart doesn't create one)
- a `demo` namespace with `app-v1` and `app-v2` (`hashicorp/http-echo`) and their Services
- a `Gateway` `demo` with one HTTP listener on port 80. Its `infrastructure.parametersRef` points to the `EnvoyProxy` `nodeport`, which turns the generated proxy Service into NodePort 30081 (kind has no LoadBalancer). `kind-config.yaml` maps that port to http://localhost:8085.
- an `HTTPRoute` `app` that sends everything to `app-v1`

## Prerequisites

`kind`, `kubectl`, `helm`, and docker or podman. See [../prometheus-operator/README.md](../prometheus-operator/README.md#prerequisites) for the inotify sysctl. Without it, a second kind cluster fails at "Preparing nodes".

## Usage

```sh
./up.sh
./down.sh
```

```sh
alias k='kubectl --context kind-gateway-api -n demo'

curl localhost:8085                                     # app v1
k get gateway,httproute                                 # PROGRAMMED True
k get httproute app -o jsonpath='{.status.parents[0].conditions}'   # Accepted, ResolvedRefs
kubectl --context kind-gateway-api -n envoy-gateway-system get pods,svc   # envoy-demo-demo-* proxy
```

## Traffic split and header match

`manifests/split.yaml` replaces the `app` route. Requests with `x-version: v2` always go to `app-v2`, everything else is split 90/10.

```sh
kubectl --context kind-gateway-api apply -f manifests/split.yaml
for i in $(seq 100); do curl -s localhost:8085; done | sort | uniq -c   # ~90 v1, ~10 v2
curl -H 'x-version: v2' localhost:8085                                  # app v2

kubectl --context kind-gateway-api apply -f manifests/demo.yaml          # back to v1 only
```

## Trying other resources

To add a listener, edit the `Gateway` or attach a `ListenerSet`. Each new listener port needs a fixed `nodePort` in the `EnvoyProxy` patch and a matching `extraPortMappings` entry in `kind-config.yaml`. Changing `kind-config.yaml` means recreating the cluster. Envoy Gateway's own extensions (`ClientTrafficPolicy`, `BackendTrafficPolicy`, `SecurityPolicy`, ...) are installed too: `kubectl api-resources | grep envoyproxy`.

Reset the scenario:

```sh
kubectl --context kind-gateway-api delete ns demo && kubectl --context kind-gateway-api apply -f manifests/demo.yaml
```
