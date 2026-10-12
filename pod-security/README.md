# pod-security

Minimal single-node kind cluster for [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/) (PSA) and the [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) `privileged`, `baseline` and `restricted`. PSA is built into the API server, so nothing is installed; it is configured with namespace labels only.

`up.sh` creates one namespace per standard (`manifests/namespaces.yaml`). Each enforces its standard and warns about anything that is not `restricted`-compliant.

Each test pod in `manifests/pods/` fulfils exactly one standard. Result of `kubectl apply` per namespace:

| Pod | psa-privileged | psa-baseline | psa-restricted |
|---|---|---|---|
| `privileged.yaml` | allowed + warning | **denied** | **denied** |
| `baseline.yaml` | allowed + warning | allowed + warning | **denied** |
| `restricted.yaml` | allowed | allowed | allowed |

## Prerequisites

`kind`, `kubectl`, and docker or podman. See [../prometheus-operator/README.md](../prometheus-operator/README.md#prerequisites) for the inotify sysctl. Without it, a second kind cluster fails at "Preparing nodes".

## Usage

```sh
./up.sh
./down.sh
```

```sh
alias k='kubectl --context kind-pod-security'

k get ns -L pod-security.kubernetes.io/enforce,pod-security.kubernetes.io/warn

# enforce: rejected
k -n psa-restricted apply -f manifests/pods/baseline.yaml
# -> forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false ...

# warn: admitted, with a Warning line listing what restricted would reject
k -n psa-baseline apply -f manifests/pods/baseline.yaml

# compliant
k -n psa-restricted apply -f manifests/pods/restricted.yaml

# Workloads only get warnings. The Deployment is created, but the
# ReplicaSet can't create pods:
k -n psa-restricted apply -f manifests/deployment-baseline.yaml
k -n psa-restricted get events --field-selector reason=FailedCreate

# Which existing pods would break if a namespace were tightened?
k label --dry-run=server --overwrite ns psa-baseline pod-security.kubernetes.io/enforce=restricted
```

Reset the scenario:

```sh
kubectl --context kind-pod-security delete -f manifests/namespaces.yaml && kubectl --context kind-pod-security apply -f manifests/namespaces.yaml
```
