# opencost

Single-node kind cluster with [OpenCost](https://www.opencost.io/) (cost-model + UI) backed by a minimal Prometheus (`prometheus-community/prometheus`, no Alertmanager / Pushgateway), installed as described in the [on-prem docs](https://opencost.io/docs/configuration/on-prem).

kind has no cloud billing API, so `opencost-values.yaml` enables **custom pricing** with a static price list (per vCPU-hour, GiB-RAM-hour, GiB-storage-month). Edit `opencost.customPricing.costModel` and re-run `./up.sh` to change it.

## Prerequisites

`kind`, `kubectl`, `helm`, and docker or podman. See [../prometheus-operator/README.md](../prometheus-operator/README.md#prerequisites) for the inotify sysctl.

## Usage

```sh
./up.sh
./down.sh
```

| What | URL |
|---|---|
| OpenCost UI | http://localhost:9095 |
| OpenCost API | http://localhost:9095/model/... (proxied by the UI) |
| Prometheus | http://localhost:9096 |

Allocation data needs a few minutes of Prometheus history before it appears (the cost-model queries at 5m resolution).

```sh
# Cost per namespace over the last hour
curl -s 'http://localhost:9095/model/allocation?window=1h&aggregate=namespace' | jq '.data[0] | map_values(.totalCost)'

# Per team label, last 24h
curl -s 'http://localhost:9095/model/allocation?window=24h&aggregate=label:team' | jq '.data[0] | map_values(.totalCost)'

# Node / asset costs
curl -s 'http://localhost:9095/model/assets?window=1h' | jq '.data[0] | map_values(.totalCost)'
```

Prometheus scrapes OpenCost itself (job `opencost`), so cost metrics such as `node_total_hourly_cost`, `container_cpu_allocation` and `pod_pvc_allocation` are queryable at http://localhost:9096.

## Demo apps

`manifests/demo-apps.yaml` creates two "teams" with different resource profiles so the allocation views have something to show:

| Namespace | Deployment | Replicas | CPU req | Mem req | Behaviour |
|---|---|---|---|---|---|
| `team-a` | web | 3 | 100m | 128Mi | idle |
| `team-a` | worker | 1 | 100m | 256Mi | burns ~200m CPU (usage > request) |
| `team-b` | api | 2 | 50m | 64Mi | idle |
| `team-b` | batch | 1 | 500m | 512Mi | idle, over-provisioned (low efficiency) |

All pods carry `team` and `app` labels, so you can aggregate by `namespace`, `label:team` or `label:app`.
