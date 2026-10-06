# prometheus-operator

Single-node kind cluster with the full [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack): Prometheus Operator, Prometheus, Alertmanager, Grafana (with default dashboards), node-exporter and kube-state-metrics.

The kind config binds the controller-manager, scheduler, etcd and kube-proxy metrics endpoints to `0.0.0.0` so those targets actually get scraped.

## Prerequisites

`kind`, `kubectl`, `helm`, and docker or podman. Kind nodes need more inotify instances than most distros allow by default (Fedora: 128), otherwise containerd / Prometheus fail with `too many open files`:

```sh
sudo sysctl fs.inotify.max_user_instances=512 fs.inotify.max_user_watches=524288
# persist:
printf "fs.inotify.max_user_instances=512\nfs.inotify.max_user_watches=524288\n" | sudo tee /etc/sysctl.d/99-kind.conf
```

## Usage

```sh
./up.sh
./down.sh
```

| What | URL | Credentials |
|---|---|---|
| Grafana | http://localhost:3000 | `admin` / `admin` |
| Prometheus | http://localhost:9090 | |
| Alertmanager | http://localhost:9093 | |

ServiceMonitors, PodMonitors and PrometheusRules are picked up from every namespace, regardless of labels.

## Demo apps (namespace `demo`)

`manifests/demo-apps.yaml` deploys workloads that expose metrics, plus a `loadgen` pod producing a mix of 2xx/4xx/5xx and slow requests. **Nothing scrapes them yet** — add your own `ServiceMonitor` / `PodMonitor` (any namespace, any labels) to pick them up.

| Workload | Pattern | Service / port | Path | Interesting metrics |
|---|---|---|---|---|
| podinfo (2 replicas) | native | `podinfo:9898` (`http`) | `/metrics` | `http_requests_total`, `http_request_duration_seconds_*` |
| example-app (2 replicas) | native | `example-app:8080` (`http`) | `/metrics` | `http_requests_total{code,method}`, `version` |
| nginx | exporter sidecar | `nginx:9113` (`metrics`) | `/metrics` | `nginx_connections_*`, `nginx_http_requests_total` |
| redis | exporter sidecar | `redis:9121` (`metrics`) | `/metrics` | `redis_up`, `redis_commands_*`, `redis_memory_*` |

All pods/services carry `app.kubernetes.io/name: <workload>`. Peek at a target:

```sh
kubectl --context kind-prometheus-operator -n demo port-forward svc/podinfo 9898 &
curl -s localhost:9898/metrics | head
```
