# gatekeeper

Minimal single-node kind cluster with [OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper/) and nothing else. Gatekeeper has no UI; results are read from the constraint resources. The audit interval is lowered to 20s (`gatekeeper-values.yaml`).

`up.sh` applies the ConstraintTemplates, waits until Gatekeeper has created their constraint CRDs, then applies the constraints and the mutation. All of them only match namespaces labelled `gatekeeper-demo: enabled`.

| File | Kind | Action | Effect |
|---|---|---|---|
| `policies/constraints/require-team-label.yaml` | `K8sRequiredLabels` | `deny` | Deployments need a `team` label |
| `policies/constraints/disallow-latest-tag.yaml` | `K8sDisallowedTags` | `warn` | `:latest` or untagged images print a warning |
| `policies/constraints/require-resources.yaml` | `K8sRequiredResources` | `dryrun` | missing requests/limits only show up in the audit |
| `policies/mutations/default-team-label.yaml` | `AssignMetadata` | mutation | Pods without a `team` label get `team=unassigned` |

The Rego lives in `policies/templates/` (Rego v1 syntax). `manifests/demo-apps.yaml` deploys `good` (compliant) and `sloppy` (admitted, but `:latest`, no resources, no pod template label).

## Prerequisites

`kind`, `kubectl`, `helm`, and docker or podman. See [../prometheus-operator/README.md](../prometheus-operator/README.md#prerequisites) for the inotify sysctl. Without it, a second kind cluster fails at "Preparing nodes".

## Usage

```sh
./up.sh
./down.sh
```

```sh
alias k='kubectl --context kind-gatekeeper'

k get constrainttemplates
k get constraints                                    # enforcement action + TOTAL-VIOLATIONS

# deny
k -n demo create deployment no-team --image=nginx:1.31.6-alpine
# -> denied: [require-team-label] missing required labels: {"team"}

# warn (admitted, with a Warning line)
k -n demo create deployment latest --image=nginx:latest   # also denied: no team label
k -n demo label deploy sloppy touched=true                # Warning: [disallow-latest-tag] ...

# mutation
k -n demo get pods -L team                           # sloppy-... team=unassigned

# audit (dryrun and warn violations, refreshed every 20s)
k get k8srequiredresources require-resources \
  -o jsonpath='{range .status.violations[*]}{.name}: {.message}{"\n"}{end}'
```

`kubectl create deployment` cannot set labels, so to create a compliant Deployment imperatively: `k -n demo create deployment x --image=nginx:1.31.6-alpine --dry-run=client -o yaml | k label -f - --local team=platform -o yaml | k apply -f -`.

Reset the scenario:

```sh
kubectl --context kind-gatekeeper delete ns demo && kubectl --context kind-gatekeeper apply -f manifests/demo-apps.yaml
```
