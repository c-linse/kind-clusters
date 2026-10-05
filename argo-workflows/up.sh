#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME=argo-workflows
CONTEXT="kind-${CLUSTER_NAME}"
ARGO_CHART_VERSION=2.0.11

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --config kind-config.yaml
fi

echo "==> Deploying SeaweedFS"
kubectl --context "${CONTEXT}" apply -f manifests/seaweedfs.yaml
kubectl --context "${CONTEXT}" -n seaweedfs rollout status deploy/seaweedfs --timeout=180s
kubectl --context "${CONTEXT}" -n seaweedfs wait --for=condition=complete job/create-argo-bucket --timeout=180s

echo "==> Deploying PostgreSQL"
kubectl --context "${CONTEXT}" apply -f manifests/postgres.yaml

echo "==> Deploying Kafka (KRaft)"
kubectl --context "${CONTEXT}" apply -f manifests/kafka.yaml
kubectl --context "${CONTEXT}" apply -f manifests/kafka-ui.yaml

kubectl --context "${CONTEXT}" -n postgres rollout status deploy/postgres --timeout=300s
kubectl --context "${CONTEXT}" -n kafka rollout status deploy/kafka --timeout=300s
kubectl --context "${CONTEXT}" -n kafka rollout status deploy/kafka-ui --timeout=300s

echo "==> Installing Argo Workflows"
kubectl --context "${CONTEXT}" create namespace argo --dry-run=client -o yaml | kubectl --context "${CONTEXT}" apply -f -
kubectl --context "${CONTEXT}" apply -f manifests/argo-s3-secret.yaml
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null
helm upgrade --install argo-workflows argo/argo-workflows \
  --kube-context "${CONTEXT}" \
  --namespace argo \
  --version "${ARGO_CHART_VERSION}" \
  --values helm/argo-values.yaml \
  --wait --timeout 5m

cat <<EOF

Done.
  Argo UI:     http://localhost:2746
  SeaweedFS S3: http://localhost:8333  (access key: argo / secret: argo-secret-key)
  PostgreSQL:   localhost:5432  (in-cluster: postgres.postgres.svc:5432; app / app-secret, db "app")
  Kafka:        localhost:9094  (in-cluster: kafka.kafka.svc:9092)
  Kafka UI:     http://localhost:8080

Try it:
  kubectl --context ${CONTEXT} create -f workflows/example-workflow.yaml
  kubectl --context ${CONTEXT} -n argo get workflows -w
EOF
