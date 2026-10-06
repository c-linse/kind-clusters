# prometheus

Single-node kind cluster with plain Prometheus (`prometheus-community/prometheus` chart, no operator, no Alertmanager) and Grafana (`grafana-community/grafana`) with Prometheus preconfigured as the default datasource.

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
| Grafana | http://localhost:3001 | `admin` / `admin` |
| Prometheus | http://localhost:9091 | |

Ports differ from `../prometheus-operator` so both clusters can run side by side. Scrape config uses the chart's built-in Kubernetes SD plus `prometheus.io/scrape` pod/service annotations.

## Demo apps (namespace `demo`)

`manifests/demo-apps.yaml` deploys workloads that expose metrics, plus a `loadgen` pod producing a mix of 2xx/4xx/5xx and slow requests. **Nothing scrapes them yet** — there are no `prometheus.io/scrape` annotations on purpose, so the chart's `kubernetes-pods` / `kubernetes-service-endpoints` jobs ignore them. Add annotations or your own `scrape_configs` (`serverFiles.prometheus.yml` / `extraScrapeConfigs` in `prometheus-values.yaml`) to pick them up.

| Workload | Pattern | Service / port | Path | Interesting metrics |
|---|---|---|---|---|
| podinfo (2 replicas) | native | `podinfo:9898` (`http`) | `/metrics` | `http_requests_total`, `http_request_duration_seconds_*` |
| example-app (2 replicas) | native | `example-app:8080` (`http`) | `/metrics` | `http_requests_total{code,method}`, `version` |
| nginx | exporter sidecar | `nginx:9113` (`metrics`) | `/metrics` | `nginx_connections_*`, `nginx_http_requests_total` |
| redis | exporter sidecar | `redis:9121` (`metrics`) | `/metrics` | `redis_up`, `redis_commands_*`, `redis_memory_*` |

All pods/services carry `app.kubernetes.io/name: <workload>`. Peek at a target:

```sh
kubectl --context kind-prometheus -n demo port-forward svc/podinfo 9898 &
curl -s localhost:9898/metrics | head
```
