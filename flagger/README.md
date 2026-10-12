# flagger

Minimal single-node kind cluster with [Flagger](https://flagger.app/) and nothing else: no service mesh, no ingress, no Prometheus. Flagger runs with `meshProvider: kubernetes`, which only supports Blue/Green: it runs the analysis (webhooks, `iterations`) against the canary pods, then switches the ClusterIP Service to the new version. See the [Kubernetes Blue/Green tutorial](https://docs.flagger.app/tutorials/kubernetes-blue-green).

No Canary resources are created. You write them yourself.

## Prerequisites

`kind`, `kubectl`, `helm`, and docker or podman. See [../prometheus-operator/README.md](../prometheus-operator/README.md#prerequisites) for the inotify sysctl. Without it, a second kind cluster fails at "Preparing nodes".

## Usage

```sh
./up.sh
./down.sh
```

```sh
kubectl --context kind-flagger -n malawi get canary -w
kubectl --context kind-flagger -n flagger-system logs deploy/flagger -f | jq -r .msg
```

## CNPE practice: Blue/Green without a mesh (`malawi`)

`manifests/malawi.yaml` mirrors a CNPE simulator task. Two `hashicorp/http-echo` apps answer with their `APP_VERSION`. The `appN-nodeport` Services select the `appN-primary` pods, so the URLs below only answer after you create a Canary for that app and it reaches `Initialized`. The Canaries are commented out in the manifest as a reference.

**Step 0** (the exam has this already): create a Canary for `app1` and `app2` targeting the Deployment, with `service.port: 80`, `targetPort: 8080` and the analysis from the template below (without webhooks).

| App | URL |
|---|---|
| app1 | http://localhost:30041 |
| app2 | http://localhost:30042 |

**Task** (namespace `malawi`):

1. For Deployment `app1`, bump the patch number of env `APP_VERSION` by 1. Write the events triggered on the Canary resource into `/course/4/app1.log`.
2. For Deployment `app2`, add a basic `pre-rollout` webhook to the Canary analysis that checks via HTTP whether the new Pods respond, using the canary Service. Then trigger a rollout by setting `APP_VERSION` to `1.0.1`. Template:

```yaml
analysis:
  interval: 5s
  iterations: 2
  metrics: []
  webhooks:
    - name: "basic-http-test"
      type: pre-rollout
      url: http://TODO # DNS to canary service
      timeout: 5s
      metadata:
        type: "http"
        method: "GET"
        expectedStatus: "200"
```

Reset the scenario. Deleting only a Canary leaves its Deployment scaled to 0, so re-apply the manifest afterwards:

```sh
kubectl --context kind-flagger delete ns malawi && kubectl --context kind-flagger apply -f manifests/malawi.yaml
```

<details>
<summary>Solution</summary>

```sh
alias k='kubectl --context kind-flagger -n malawi'

# 0. Canaries: uncomment them in manifests/malawi.yaml and apply, or:
for a in app1 app2; do k apply -f - <<YAML
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: $a
spec:
  targetRef: {apiVersion: apps/v1, kind: Deployment, name: $a}
  service: {port: 80, targetPort: 8080}
  analysis: {interval: 5s, iterations: 2, threshold: 2, metrics: []}
YAML
done
k get canary -w                              # wait for Initialized

# 1. app1
k set env deploy/app1 APP_VERSION=1.0.1
k get canary app1 -w                         # wait for Succeeded
k events --for canary/app1 > /tmp/app1.log   # /course/4/app1.log in the exam
# (or: k describe canary app1 and copy the Events section)

# 2. app2: add the webhook (k edit canary app2 works too)
k patch canary app2 --type merge -p '{"spec":{"analysis":{"webhooks":[{
  "name":"basic-http-test","type":"pre-rollout",
  "url":"http://app2-canary.malawi","timeout":"5s",
  "metadata":{"type":"http","method":"GET","expectedStatus":"200"}}]}}}'
k set env deploy/app2 APP_VERSION=1.0.1
k events --for canary/app2 | grep -i pre-rollout   # "Pre-rollout check basic-http-test passed"
curl localhost:30042                               # app2 1.0.1
```

The webhook URL is the Flagger-created canary Service, `app2-canary.malawi` (port 80, the Canary's `service.port`). Flagger POSTs to it and treats any 2xx as a pass; the `metadata` is just passed along in the payload. Point it at something wrong and the rollout should stall on a failed pre-rollout check, then roll back after `threshold` failures (not tested here).

</details>
