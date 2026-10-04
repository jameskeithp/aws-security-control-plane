# AWS Security Control Plane

A production-style AWS security baseline: hardened S3 foundations, centralized
logging (CloudTrail), configuration compliance (AWS Config), detective
services (GuardDuty, Security Hub, Macie, Inspector), and an **automated
remediation engine** that fixes risky S3 buckets the moment Security Hub
flags them — deployed entirely with Terraform and GitHub Actions OIDC
(no long-lived AWS keys).

```
                    ┌─────────────────────────────┐
                    │        GitHub Actions       │
                    │   (OIDC → IAM role, no keys)│
                    └──────────────┬──────────────┘
                                   │ terraform apply
                    ┌──────────────▼──────────────┐
                    │      AWS Account (dev)      │
                    │                             │
  ┌─────────┐      │  ┌────────┐   ┌───────────┐  │
  │ S3 logs │◄─────┤  │Cloud-  │   │  Config   │  │
  │ bucket  │      │  │Trail   │   │  Rules    │  │
  └─────────┘      │  └────────┘   └───────────┘  │
                   │  ┌────────────────────────┐ │
                   │  │ GuardDuty · Security   │ │
                   │  │ Hub · Macie · Inspector│ │
                   │  └───────────┬────────────┘ │
                   │              │ finding      │
                   │  ┌───────────▼────────────┐ │
                   │  │ EventBridge rule       │ │
                   │  └───────────┬────────────┘ │
                   │  ┌───────────▼────────────┐ │
                   │  │ Lambda remediation     │ │
                   │  │ engine (dry-run first) │ │
                   │  └────────────────────────┘ │
                   └─────────────────────────────┘
```

## Features

- **Secure S3 baseline** — every bucket ships with Block Public Access,
  default SSE, and versioning; bucket policies deny unencrypted uploads and
  non-TLS traffic (`policies/`).
- **Centralized audit trail** — multi-region CloudTrail with log-file
  validation, delivered to a hardened, versioned logs bucket.
- **Compliance as code** — AWS Config recorder + managed rules for S3,
  CloudTrail, and public-access hygiene.
- **Detective services** — GuardDuty, Security Hub (with security standards
  auto-enabled), Macie, and Inspector v2, all in one module.
- **Automated remediation** — an EventBridge rule routes Security Hub S3
  findings to a Lambda that applies guardrails (public-access block,
  encryption, versioning) with an idempotent remediate→verify flow.
  Ships in **dry-run mode by default**; buckets tagged
  `SecurityRemediation=disabled` are excluded.
- **Keyless CI/CD** — GitHub Actions assumes an IAM role via OIDC, scoped to
  this repository's `main` branch (legacy and post-July-2026 immutable
  subject formats supported).

## Repository Layout

```
.
├── terraform/
│   ├── modules/
│   │   ├── s3-security/         # Hardened logs bucket
│   │   ├── cloudtrail/          # Multi-region trail + bucket policy
│   │   ├── config/              # Recorder, delivery channel, rules
│   │   ├── security-services/   # GuardDuty, Security Hub, Macie, Inspector
│   │   ├── lambda-remediation/  # Remediation Lambda + IAM + packaging
│   │   └── eventbridge/         # Security Hub → Lambda routing
│   └── environments/dev/        # Wiring, OIDC role, versions, example tfvars
├── lambda/remediation/          # Remediation engine (handler.py + tests)
├── policies/                    # Example S3 / IAM / network policies (JSON)
├── tests/                       # Policy + fixture tests
├── scripts/                     # bootstrap.sh, validate.sh, destroy.sh
├── docs/                        # deployment, remediation, IR, NIST, evidence
└── .github/workflows/           # terraform, tests, security (Trivy), OIDC smoke test
```

## Quickstart

Prerequisites: Terraform >= 1.6, AWS CLI v2, Python >= 3.12, and AWS
credentials with permission to create the resources (or the GitHub OIDC role).

```bash
# 1. Configure
cp terraform/environments/dev/terraform.tfvars.example \
   terraform/environments/dev/terraform.tfvars
# edit terraform.tfvars: github_org, github_repo, region, tags

# 2. Bootstrap (prereq checks + terraform init)
bash scripts/bootstrap.sh

# 3. Review and apply
cd terraform/environments/dev
terraform plan -out=tfplan
terraform apply tfplan
```

For the full walkthrough, see [docs/deployment.md](docs/deployment.md).

## The Remediation Engine

`lambda/remediation/handler.py` is the heart of the project:

1. **Event validation** — accepts only `Security Hub Findings - Imported`
   events; anything else is rejected with a structured log.
2. **Allowlist** — only `AwsS3Bucket` resources from AWS Security Best
   Practices findings are processed; everything else is skipped, never failed.
3. **Exception tag** — buckets tagged `SecurityRemediation=disabled` are left
   alone (escape hatch for break-glass workloads).
4. **Dry-run default** — `DRY_RUN=true` unless explicitly disabled. In dry-run
   the engine reports what it *would* change without touching anything.
5. **Idempotent remediate→verify** — each control is checked first; only
   non-compliant settings are changed, then re-read to verify. Already-clean
   buckets produce zero API mutations.

Applied guardrails per bucket:

| Control | Remediation |
| ------- | ----------- |
| Public access | `PutPublicAccessBlock` — all four block flags `true` |
| Encryption | `PutBucketEncryption` — SSE-S3 (AES256) default |
| Versioning | `PutBucketVersioning` — `Enabled` |

Details and runbook: [docs/remediation.md](docs/remediation.md).

## Configuration

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `project_name` | `aws-security-control-plane` | Prefix for all resource names/tags |
| `environment` | `dev` | Environment label |
| `aws_region` | `us-east-1` | Deployment region |
| `github_org` / `github_repo` | — | Repo allowed to assume the deploy role |
| `dry_run` | `"true"` | Lambda `DRY_RUN` env (`"false"` enables live remediation) |
| `enable_macie` / `enable_inspector` | `true` | Toggle detective services |

## CI/CD

- `terraform.yml` — fmt / validate / plan on PRs; apply on `main` (Terraform
  1.14.6 via `setup-terraform@v4`, AWS creds via OIDC).
- `tests.yml` — pytest across Lambda unit tests and policy tests.
- `security.yml` — Trivy v0.36.0 filesystem + IaC scan (no Checkov).
- `oidc-smoke-test.yml` — verifies the GitHub OIDC role assumption works.

## Docs

- [Deployment guide](docs/deployment.md)
- [Remediation engine](docs/remediation.md)
- [Incident response runbook](docs/incident-response.md)
- [NIST CSF / 800-53 mapping](docs/nist-mapping.md)
- [Evidence collection](docs/evidence.md)

## Security

See [SECURITY.md](SECURITY.md). Report vulnerabilities privately — never in a
public issue.

## License

MIT — see [LICENSE](LICENSE).
