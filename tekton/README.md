# tekton

Single-node kind cluster with Tekton Pipelines core only (no Triggers / EventListeners, no Chains, no Dashboard).

## Prerequisites

`kind`, `kubectl`, [`tkn`](https://tekton.dev/docs/cli/), and docker or podman. Kind nodes need more inotify instances than most distros allow by default (Fedora: 128), otherwise node creation fails with `could not find a log line that matches "Reached target .*Multi-User System.*"` (especially with other kind clusters running):

```sh
sudo sysctl fs.inotify.max_user_instances=512 fs.inotify.max_user_watches=524288
# persist:
printf "fs.inotify.max_user_instances=512\nfs.inotify.max_user_watches=524288\n" | sudo tee /etc/sysctl.d/99-kind.conf
```

## Usage

```sh
./up.sh      # create cluster, install Tekton Pipelines, apply example Tasks + Pipeline
./down.sh    # delete cluster
```

All commands below assume the kind context is active:

```sh
kubectl config use-context kind-tekton
```

## Files

- `up.sh` / `down.sh` – create / delete the cluster
- `kind-config.yaml` – cluster definition
- `tasks/`
  - `hello.yaml` – prints `Hello, <name>!` and emits it as the result `greeting`
  - `write-file.yaml` – writes param `message` to `message.txt` on workspace `output`
  - `read-file.yaml` – prints `message.txt` from workspace `input`
- `pipelines/hello-pipeline.yaml` – `hello` → `write` → `read`, passing the result into a param and the file over the `shared` workspace
- `runs/`
  - `hello-taskrun.yaml` / `hello-pipelinerun.yaml` – declarative runs (use `kubectl create`, they use `generateName`)
  - `workspace-template.yaml` – PVC template for `tkn pipeline start`

## Running

### Task

```sh
# with tkn
tkn task start hello --use-param-defaults --showlog
tkn task start hello -p name=Alice --showlog

# declaratively
kubectl create -f runs/hello-taskrun.yaml
tkn taskrun logs --last -f
```

### Pipeline

```sh
# with tkn (workspace backed by a fresh PVC per run)
tkn pipeline start hello-pipeline -p name=Alice \
  --workspace name=shared,volumeClaimTemplateFile=runs/workspace-template.yaml \
  --showlog

# declaratively
# (the workspace must be a PVC: an emptyDir is per pod, so read-file wouldn't see the file)
kubectl create -f runs/hello-pipelinerun.yaml
tkn pipelinerun logs --last -f
```

## tkn cheat sheet

```sh
# inspect
tkn task list
tkn task describe hello
tkn pipeline list
tkn pipeline describe hello-pipeline

# runs
tkn taskrun list
tkn taskrun describe --last
tkn taskrun logs <name> -f
tkn pipelinerun list
tkn pipelinerun describe --last
tkn pipelinerun logs <name> -f

# re-run the last run with the same params/workspaces
tkn pipeline start hello-pipeline --last --showlog

# cancel / clean up
tkn pipelinerun cancel <name>
tkn taskrun delete --all -f
tkn pipelinerun delete --all -f

# versions (client + server)
tkn version
```

## Raw kubectl equivalents

```sh
kubectl get tasks,pipelines
kubectl get taskruns,pipelineruns
kubectl get pods -l tekton.dev/pipelineRun=<name>
kubectl logs <pod> --all-containers
```
