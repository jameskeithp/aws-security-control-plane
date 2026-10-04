#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# validate.sh — static validation for the whole repository:
#   terraform fmt + validate, Python compile, JSON lint, shell syntax.
# ------------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

failures=0

echo "==> terraform fmt -check"
if ! terraform fmt -check -recursive terraform; then
  echo "ERROR: terraform files need formatting (run: terraform fmt -recursive terraform)" >&2
  failures=$((failures + 1))
fi

echo "==> python compile check"
if ! python3 -m compileall -q lambda tests; then
  echo "ERROR: python compile check failed" >&2
  failures=$((failures + 1))
fi

echo "==> JSON lint"
for f in policies/*.json tests/fixtures/*.json; do
  if ! python3 -c "import json,sys; json.load(open('$f'))" 2>/dev/null; then
    echo "ERROR: invalid JSON: $f" >&2
    failures=$((failures + 1))
  fi
done

echo "==> shell syntax check"
for f in scripts/*.sh; do
  if ! bash -n "$f"; then
    echo "ERROR: shell syntax error: $f" >&2
    failures=$((failures + 1))
  fi
done

if [[ "$failures" -gt 0 ]]; then
  echo ""
  echo "VALIDATION FAILED ($failures problem(s))" >&2
  exit 1
fi

echo ""
echo "All validation checks passed."
