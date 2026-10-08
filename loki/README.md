# loki

Single-node kind cluster with Grafana Loki (`grafana-community/loki` chart, monolithic / single binary, filesystem storage, no auth), Grafana Alloy collecting every pod's logs, and Grafana (`grafana-community/grafana`) with Loki preconfigured as the default datasource.

## Prerequisites

`kind`, `kubectl`, `helm`, and docker or podman. Kind nodes need more inotify instances than most distros allow by default (Fedora: 128), otherwise node creation fails with `could not find a log line that matches "Reached target .*Multi-User System.*"` (especially with other kind clusters running):

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
| Grafana | http://localhost:3002 | `admin` / `admin` |
| Loki (gateway) | http://localhost:3100 | none (`auth_enabled: false`) |

Ports differ from `../prometheus` and `../prometheus-operator` so the clusters can run side by side.

## Files

- `up.sh` / `down.sh` – create / delete the cluster
- `kind-config.yaml` – cluster definition + host port mappings
- `loki-values.yaml` – Loki: monolithic, `replication_factor: 1`, TSDB/v13 schema on a 5Gi PVC, 72h retention, no memcached caches / canary / helm test
- `alloy-values.yaml` – Alloy (namespace `logging`): one Deployment replica tailing pod logs via the Kubernetes API (`loki.source.kubernetes`), pushing to `loki-gateway.loki.svc`
- `grafana-values.yaml` – Grafana (namespace `monitoring`) with the Loki datasource
- `manifests/demo-apps.yaml` – log generators in namespace `demo`

## Labels

Alloy attaches these stream labels to every pod's logs:

| Label | Source |
|---|---|
| `namespace`, `pod`, `container`, `node` | pod metadata |
| `app` | pod label `app.kubernetes.io/name` |
| `service_name` | `app`, falling back to the container name (used by Grafana's Logs Drilldown) |
| `level` | parsed from `level=`/`"level":` in the line, if present |

## Demo apps (namespace `demo`)

| Workload | Format | Example |
|---|---|---|
| flog-json | JSON access log | `{"host":"…","method":"GET","request":"/…","status":503,"bytes":…}` |
| flog-apache | Apache combined | `1.2.3.4 - - [07/Oct/2026:…] "GET /… HTTP/1.1" 200 …` |
| orders (2 replicas) | logfmt with `level`, `trace_id`, `duration_ms` | `level=error msg="payment failed" order_id=42 … status=502` |

## LogQL to try

In Grafana → Explore (or **Drilldown → Logs**):

```logql
{namespace="demo"}
{app="orders", level="error"}
{app="orders"} | logfmt | duration_ms > 500
{app="flog-json"} | json | status >= 500
sum by (status) (count_over_time({app="flog-json"} | json [1m]))
sum by (level) (rate({app="orders"}[1m]))
quantile_over_time(0.95, {app="orders"} | logfmt | unwrap duration_ms [1m]) by (pod)
```

Straight against the API:

```sh
curl -s localhost:3100/loki/api/v1/labels | jq
curl -s localhost:3100/loki/api/v1/label/app/values | jq
curl -sG localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={app="orders", level="error"}' --data-urlencode 'limit=5' | jq '.data.result[].values'

# push a line yourself
curl -s -H 'Content-Type: application/json' localhost:3100/loki/api/v1/push --data-raw \
  "{\"streams\":[{\"stream\":{\"app\":\"manual\"},\"values\":[[\"$(date +%s%N)\",\"hello loki\"]]}]}"
```

With [`logcli`](https://grafana.com/docs/loki/latest/query/logcli/):

```sh
export LOKI_ADDR=http://localhost:3100
logcli labels
logcli query '{app="orders"} |= "payment"' --since=10m
logcli query --tail '{namespace="demo"}'
```
