#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# bootstrap.sh — verify prerequisites and initialize the dev Terraform backend.
# ------------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$REPO_ROOT/terraform/environments/dev"

echo "==> Checking prerequisites..."
command -v terraform >/dev/null 2>&1 || { echo "ERROR: terraform not found (need >= 1.6)" >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI not found" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found" >&2; exit 1; }
echo "    terraform: $(terraform version -json | python3 -c 'import json,sys; print(json.load(sys.stdin)["terraform_version"])')"
echo "    aws CLI:   $(aws --version 2>&1 | head -n1)"
echo "    python:    $(python3 --version)"

if [[ ! -f "$TF_DIR/terraform.tfvars" ]]; then
  echo ""
  echo "WARNING: $TF_DIR/terraform.tfvars not found."
  echo "Copy the example and fill in your values:"
  echo "  cp $TF_DIR/terraform.tfvars.example $TF_DIR/terraform.tfvars"
fi

echo ""
echo "==> Running terraform init..."
cd "$TF_DIR"
terraform init

echo ""
echo "Bootstrap complete. Next steps:"
echo "  cd $TF_DIR"
echo "  terraform plan -out=tfplan"
echo "  terraform apply tfplan"
