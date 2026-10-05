#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

kind delete cluster --name opentofu
# State refers to resources that no longer exist once the cluster is gone.
rm -f tofu/terraform.tfstate tofu/terraform.tfstate.backup
