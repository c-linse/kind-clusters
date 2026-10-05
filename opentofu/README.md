# opentofu

Single-node kind cluster for playing with [OpenTofu](https://opentofu.org) and the `hashicorp/kubernetes` provider. The `tofu/` project creates a namespace, an nginx Deployment and a NodePort Service.

## Prerequisites

`kind`, `kubectl`, `tofu`, and docker or podman. Kind nodes need more inotify instances than most distros allow by default (Fedora: 128), otherwise containerd fails with `too many open files`:

```sh
sudo sysctl fs.inotify.max_user_instances=512 fs.inotify.max_user_watches=524288
# persist:
printf "fs.inotify.max_user_instances=512\nfs.inotify.max_user_watches=524288\n" | sudo tee /etc/sysctl.d/99-kind.conf
```

## Usage

```sh
./up.sh      # create cluster, tofu init + apply
./down.sh    # delete cluster and local tofu state
```

| What | URL |
|---|---|
| Demo app (nginx) | http://localhost:8080 |

Iterate on the project directly:

```sh
cd tofu
tofu plan
tofu apply -var replicas=3 -var image=nginx:1.29
tofu destroy
```

## Files

- `kind-config.yaml` – cluster + host port mapping (NodePort 30080 → localhost:8080)
- `tofu/versions.tf` – required providers + kubernetes provider (kubeconfig context `kind-opentofu`)
- `tofu/variables.tf` – image, replicas, namespace, ports, …
- `tofu/main.tf` – Namespace, Deployment, NodePort Service
- `tofu/outputs.tf` – names + URL

State is local (`tofu/terraform.tfstate`, git-ignored).
