# Contributing

Thanks for your interest in contributing to `aws-security-control-plane`!

## Getting Started

1. Fork the repository and clone your fork.
2. Install prerequisites: Terraform >= 1.6, Python >= 3.12, AWS CLI v2.
3. Copy `terraform/environments/dev/terraform.tfvars.example` to
   `terraform.tfvars` and fill in your values (never commit real credentials
   or account IDs).

## Development Workflow

1. Create a feature branch: `git checkout -b feat/short-description`.
2. Make your changes, following the style rules below.
3. Run the full validation suite: `bash scripts/validate.sh` and `make test`.
4. Run `terraform fmt -recursive terraform` before committing.
5. Open a pull request against `main` with a clear description of the change
   and its security impact.

## Style Rules

- **Terraform:** every module exposes `variables.tf` / `outputs.tf`; no
  hardcoded account IDs or regions (use variables and data sources); every
  S3 bucket must keep Block Public Access, encryption, and versioning.
- **Python:** typed where practical, structured JSON logging, no bare
  `except:` clauses. New remediation logic must ship with unit tests and
  default to dry-run safe behavior.
- **Shell:** `set -euo pipefail` in every script; scripts must be executable.
- **Docs:** update the relevant file under `docs/` when behavior changes.

## Testing

```bash
make test        # pytest: lambda unit tests + policy/fixture tests
make lint        # python compile check + shell syntax check
bash scripts/validate.sh   # terraform fmt/validate + json lint
```

## Security Contributions

Security-sensitive changes (IAM policies, trust relationships, remediation
actions) require extra review. Please call out the blast radius in your PR
description and update `docs/` accordingly. See `SECURITY.md` for how to
report vulnerabilities privately.
