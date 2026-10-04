# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, **do not open a public issue**.

Instead, report it privately:

1. Open a [private security advisory](https://github.com/jameskeithp/aws-security-control-plane/security/advisories/new) on this repository, or
2. Email the maintainer directly with:
   - A description of the vulnerability
   - Steps to reproduce
   - The potential impact
   - Any suggested remediation

You can expect an initial response within 72 hours. If the issue is confirmed,
a fix will be prioritized and you will be credited (unless you prefer to remain
anonymous).

## Scope

This policy covers:

- Terraform modules under `terraform/` (IAM policies, trust relationships, encryption defaults)
- The Lambda remediation engine under `lambda/remediation/`
- GitHub Actions workflows under `.github/workflows/` (OIDC trust, secret handling)
- Example policies under `policies/`

## Out of Scope

- The `dev` environment configuration is an example. Review and adapt all
  settings (especially IAM permissions and the `dry_run` flag) before applying
  to production accounts.
- The Lambda ships with `DRY_RUN=true` by default. Disabling dry-run applies
  real changes to S3 buckets in your account — test in a sandbox first.

## Hardening Notes

- All S3 buckets created by this project enforce Block Public Access,
  default encryption, and versioning.
- The GitHub Actions deploy role is assumed via OIDC only (no long-lived
  access keys). The trust policy restricts `sub` to this repository's
  workflows on `refs/heads/main`.
- The remediation Lambda never deletes buckets or objects; it only applies
  preventive guardrails (public-access blocks, encryption, versioning).
- Buckets tagged `SecurityRemediation=disabled` are explicitly excluded from
  automated remediation.
