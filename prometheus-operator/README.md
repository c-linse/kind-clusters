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
