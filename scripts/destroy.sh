#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# destroy.sh — tear down the dev environment. Asks for explicit confirmation.
# ------------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$REPO_ROOT/terraform/environments/dev"

echo "WARNING: this will DESTROY the dev security control plane:"
echo "  $TF_DIR"
echo ""
read -r -p "Type DESTROY to confirm: " confirm

if [[ "$confirm" != "DESTROY" ]]; then
  echo "Aborted."
  exit 0
fi

cd "$TF_DIR"
terraform init -input=false >/dev/null
terraform destroy -auto-approve

echo "Dev environment destroyed."
