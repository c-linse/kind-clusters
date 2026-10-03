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
