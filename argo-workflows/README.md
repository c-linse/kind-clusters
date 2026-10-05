# argo-workflows

Single-node kind cluster with Argo Workflows, using SeaweedFS as the S3-compatible artifact repository (instead of MinIO).

## Prerequisites

`kind`, `kubectl`, `helm`, and docker or podman. Kind nodes need more inotify instances than most distros allow by default (Fedora: 128), otherwise containerd / Prometheus fail with `too many open files`:

```sh
sudo sysctl fs.inotify.max_user_instances=512 fs.inotify.max_user_watches=524288
# persist:
printf "fs.inotify.max_user_instances=512\nfs.inotify.max_user_watches=524288\n" | sudo tee /etc/sysctl.d/99-kind.conf
```

## Usage

```sh
./up.sh      # create cluster, deploy SeaweedFS + bucket, install Argo
kubectl --context kind-argo-workflows create -f example-workflow.yaml
./down.sh    # delete cluster
```

| What | URL | Credentials |
|---|---|---|
| Argo UI | http://localhost:2746 | none (`server` auth mode) |
| SeaweedFS S3 | http://localhost:8333 | `argo` / `argo-secret-key` |
| PostgreSQL | `localhost:5432` (in-cluster `postgres.postgres.svc:5432`) | `app` / `app-secret` (superuser), db `app` |
| Kafka (KRaft) | `localhost:9094` (in-cluster `kafka.kafka.svc:9092`) | none (PLAINTEXT) |
| Kafka UI | http://localhost:8080 | none |

## Files

- `kind-config.yaml` – cluster + host port mappings
- `seaweedfs.yaml` – all-in-one `weed server -s3`, PVC, NodePort service, bucket-creation Job
- `postgres.yaml` – PostgreSQL 17, credentials Secret, PVC, NodePort service
- `kafka.yaml` – single-node Kafka in KRaft combined mode (broker + controller), PVC, NodePort service
- `kafka-ui.yaml` – Kafbat UI for browsing topics and messages, NodePort service
- `argo-s3-secret.yaml` – S3 creds in the `argo` namespace
- `argo-values.yaml` – Helm values (default artifact repo → SeaweedFS, log archiving on)
- `example-workflow.yaml` – passes an artifact between two steps via S3
