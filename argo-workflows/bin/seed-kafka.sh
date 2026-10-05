#!/usr/bin/env bash
# Create a topic and produce a few messages via the in-cluster Kafka pod.
set -euo pipefail

CONTEXT="kind-argo-workflows"
TOPIC="${1:-demo}"
KAFKA=(kubectl --context "${CONTEXT}" -n kafka exec -i deploy/kafka --)
BIN=/opt/kafka/bin
BOOTSTRAP=localhost:9092

"${KAFKA[@]}" "${BIN}/kafka-topics.sh" --bootstrap-server "${BOOTSTRAP}" \
  --create --if-not-exists --topic "${TOPIC}" --partitions 1 --replication-factor 1

printf '%s\n' \
  '{"id":1,"msg":"hello"}' \
  '{"id":2,"msg":"from"}' \
  '{"id":3,"msg":"kafka"}' \
  | "${KAFKA[@]}" "${BIN}/kafka-console-producer.sh" --bootstrap-server "${BOOTSTRAP}" --topic "${TOPIC}"

echo "Produced 3 messages to '${TOPIC}'. Read them with:"
echo "  ${KAFKA[*]} ${BIN}/kafka-console-consumer.sh --bootstrap-server ${BOOTSTRAP} --topic ${TOPIC} --from-beginning --timeout-ms 5000"
