# linkerd

Minimal single-node kind cluster with [Linkerd](https://linkerd.io/) and the Viz extension, installed from the edge Helm charts (`linkerd-edge/linkerd-crds`, `linkerd-control-plane`, `linkerd-viz`). Stable Linkerd builds are only published by Buoyant, so the open-source edge releases are used. The `linkerd` CLI is not needed.

`up.sh` also:

- generates the identity trust anchor and issuer certificates with `openssl` into `certs/` (gitignored, reused on later runs). The Linkerd docs use the `step` CLI for this.
- installs the Gateway API CRDs. Linkerd's policy controller needs `HTTPRoute`, and `linkerd-crds` no longer installs it by default.
- exposes the Viz dashboard on http://localhost:8084 by patching the `web` Service to NodePort 30071.

`manifests/demo.yaml` adds a `demo` namespace annotated `linkerd.io/inject: enabled`, with `app-v1` and `app-v2` (`hashicorp/http-echo`), the Services `app` (selects v1 only), `app-v1` and `app-v2`, and a `client` pod that curls `http://app` every half second.

## Prerequisites

`kind`, `kubectl`, `helm`, `openssl`, and docker or podman. See [../prometheus-operator/README.md](../prometheus-operator/README.md#prerequisites) for the inotify sysctl. Without it, a second kind cluster fails at "Preparing nodes".

The [linkerd CLI](https://linkerd.io/2/getting-started/#step-1-install-the-cli) is optional but handy for `linkerd check`, `linkerd viz stat` and `linkerd viz tap`.

## Usage

```sh
./up.sh
./down.sh
```

```sh
alias k='kubectl --context kind-linkerd -n demo'

k get pods                        # READY 2/2: app + linkerd-proxy
k logs deploy/client -f           # app v1, app v1, ...
```

Viz dashboard: http://localhost:8084 (namespace `demo` shows success rate, RPS and latency per deployment, and that the traffic is mTLS'd).

## Traffic split with HTTPRoute

`manifests/split.yaml` attaches an `HTTPRoute` to the `app` Service and sends 90% to `app-v1`, 10% to `app-v2`. Linkerd applies it in the caller's proxy, so only meshed clients (like `client`) see the split.

```sh
kubectl --context kind-linkerd apply -f manifests/split.yaml
k get httproute app-split -o jsonpath='{.status.parents[0].conditions}'   # Accepted, ResolvedRefs
k logs deploy/client --tail=100 | sort | uniq -c                         # ~90 v1, ~10 v2

# Shift everything to v2
k patch httproute app-split --type json -p '[
  {"op":"replace","path":"/spec/rules/0/backendRefs/0/weight","value":0},
  {"op":"replace","path":"/spec/rules/0/backendRefs/1/weight","value":100}]'

kubectl --context kind-linkerd delete -f manifests/split.yaml           # back to v1 only
```

## Frontend and backend with Servers

`manifests/frontend-backend.yaml` adds `frontend` (curl) and `backend` (nginx). Each has its own ServiceAccount and a `Server` with `accessPolicy: all-authenticated`. The frontend calls `http://backend` every half second. curl doesn't listen on any port, so the `frontend` Server on port 8080 only takes effect once something in that pod serves on 8080.

```sh
kubectl --context kind-linkerd apply -f manifests/frontend-backend.yaml
k get servers                     # backend, frontend: http HTTP/1 all-authenticated
k logs deploy/frontend -f         # 200, 200, ...
```

Reset the scenario:

```sh
kubectl --context kind-linkerd delete ns demo && kubectl --context kind-linkerd apply -f manifests/demo.yaml
```

The issuer certificate is valid for 365 days. Delete `certs/` and recreate the cluster to start over with fresh certificates.
