# argo-rollouts

Minimal single-node kind cluster with [Argo Rollouts](https://argoproj.github.io/rollouts/) and nothing else: no service mesh, no ingress, no Prometheus. Without a traffic router, a canary shifts traffic by scaling ReplicaSets, so `setWeight` is only approximated by the ratio of canary to stable pods. See [Canary without traffic routing](https://argo-rollouts.readthedocs.io/en/stable/features/canary/).

The Helm chart also installs the Argo Rollouts dashboard on http://localhost:3110. `manifests/demo.yaml` adds a `demo` namespace with a `Rollout` named `app` (4 replicas of `hashicorp/http-echo`, answering with its `APP_VERSION`) and a NodePort Service on http://localhost:30051.

## Prerequisites

`kind`, `kubectl`, `helm`, and docker or podman. See [../prometheus-operator/README.md](../prometheus-operator/README.md#prerequisites) for the inotify sysctl. Without it, a second kind cluster fails at "Preparing nodes".

The [kubectl plugin](https://argo-rollouts.readthedocs.io/en/stable/installation/#kubectl-plugin-installation) is needed for `promote`/`abort` and the watch view:

```sh
curl -Lo ~/.local/bin/kubectl-argo-rollouts \
  https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x ~/.local/bin/kubectl-argo-rollouts
```

## Usage

```sh
./up.sh
./down.sh
```

```sh
kubectl argo rollouts --context kind-argo-rollouts -n demo get rollout app -w
kubectl --context kind-argo-rollouts -n argo-rollouts logs deploy/argo-rollouts -f
```

## Canary release

The steps in `manifests/demo.yaml`: 25% (1 of 4 pods), pause until promoted, 50%, wait 10s, 75%, wait 10s, then full promotion.

```sh
# Plugin flags go after `argo rollouts`: `kubectl --context X argo rollouts` is not found
alias k='kubectl --context kind-argo-rollouts -n demo'
alias kar='kubectl argo rollouts --context kind-argo-rollouts -n demo'

kar get rollout app -w

# Start a rollout (kubectl set env does not work on Rollouts)
k patch rollout app --type json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/value","value":"1.0.1"}]'

# Roughly 1 in 4 requests hits the canary
for i in $(seq 20); do curl -s localhost:30051; done | sort | uniq -c

# Continue past the indefinite pause, or abort and go back to stable
kar promote app
kar abort app      # then: kar retry rollout app
```

Reset the scenario:

```sh
kubectl --context kind-argo-rollouts delete ns demo && kubectl --context kind-argo-rollouts apply -f manifests/demo.yaml
```

## Blue-green release

`manifests/bluegreen.yaml` adds a `bluegreen` namespace with a `Rollout` named `bg` (2 replicas) and two NodePort Services:

| Service      | URL                    | Points to                          |
|--------------|------------------------|------------------------------------|
| `bg-active`  | http://localhost:30052 | stable ("blue"), production traffic |
| `bg-preview` | http://localhost:30053 | new revision ("green"), for testing |

The controller pins each Service to a ReplicaSet by adding the `rollouts-pod-template-hash` selector. Traffic does not shift gradually. On promote, `bg-active` moves from blue to green all at once. Blue stays up for `scaleDownDelaySeconds` (30s), so an abort in that window takes effect immediately.

```sh
alias kb='kubectl --context kind-argo-rollouts -n bluegreen'
alias karb='kubectl argo rollouts --context kind-argo-rollouts -n bluegreen'

karb get rollout bg -w

# Deploy green: it scales up next to blue, only bg-preview points to it
kb patch rollout bg --type json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/value","value":"green"}]'

curl -s localhost:30052   # bg blue   (active, unchanged)
curl -s localhost:30053   # bg green  (preview)

# Switch production traffic to green (or: karb abort bg)
karb promote bg
# without the plugin: kb patch rollout bg --subresource=status --type merge -p '{"status":{"pauseConditions":null}}'
curl -s localhost:30052   # bg green

# See which ReplicaSet each Service selects
kb get svc -o custom-columns=NAME:.metadata.name,HASH:.spec.selector.rollouts-pod-template-hash
```

Reset: `kubectl --context kind-argo-rollouts delete ns bluegreen && kubectl --context kind-argo-rollouts apply -f manifests/bluegreen.yaml`
