#!/usr/bin/env bash
# Create a table and insert a few rows via the in-cluster PostgreSQL pod.
set -euo pipefail

CONTEXT="kind-argo-workflows"

kubectl --context "${CONTEXT}" -n postgres exec -i deploy/postgres -- \
  sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' <<'SQL'
CREATE TABLE IF NOT EXISTS demo (
  id         serial PRIMARY KEY,
  msg        text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO demo (msg) VALUES ('hello'), ('from'), ('postgres');
SELECT * FROM demo;
SQL
