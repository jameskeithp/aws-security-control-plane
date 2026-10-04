# Deployment Guide

End-to-end deployment of the AWS Security Control Plane into the `dev`
environment.

## Prerequisites

| Tool | Minimum version | Check |
| ---- | --------------- | ----- |
| Terraform | 1.6 | `terraform version` |
| AWS CLI | v2 | `aws --version` |
| Python | 3.12 | `python3 --version` |

You also need AWS credentials able to create IAM roles, S3 buckets,
CloudTrail, Config, GuardDuty, Security Hub, Macie, Inspector, Lambda, and
EventBridge resources — or use the GitHub OIDC path below.

## Option A: Local Deploy

```bash
# 1. Configure variables (never commit secrets or account IDs)
cp terraform/environments/dev/terraform.tfvars.example \
   terraform/environments/dev/terraform.tfvars
# Edit terraform.tfvars: github_org, github_repo, aws_region, tags, dry_run

# 2. Bootstrap: prerequisite checks + terraform init
bash scripts/bootstrap.sh

# 3. Review the plan, then apply
cd terraform/environments/dev
terraform plan -out=tfplan
terraform apply tfplan
```

> The remediation Lambda ships with `dry_run = "true"`. It will log what it
> *would* remediate without changing any bucket. Flip to `"false"` only after
> reviewing [remediation.md](remediation.md).

## Option B: GitHub Actions (OIDC, no long-lived keys)

1. Deploy once locally (Option A) so the OIDC provider and deploy role exist.
2. In the GitHub repository, add a repository variable
   `AWS_DEPLOY_ROLE_ARN` with the value of the
   `github_actions_role_arn` Terraform output.
3. Push to `main`: the `terraform.yml` workflow runs fmt/validate/plan on PRs
   and applies on merge to `main`.

## Verification Checklist

- [ ] `terraform output logs_bucket_arn` returns the hardened bucket.
- [ ] CloudTrail console shows the trail logging (multi-region, validation on).
- [ ] AWS Config shows the recorder enabled and the five managed rules evaluating.
- [ ] Security Hub shows standards enabled; GuardDuty detector is active.
- [ ] CloudWatch Logs shows `/aws/lambda/...-remediation` log group.
- [ ] Trigger a test: upload nothing — instead, run the Lambda manually with
      `tests/fixtures/securityhub-s3-finding.json` as the test event in
      dry-run mode and confirm `would-change` actions in the logs.

## Tear Down

```bash
bash scripts/destroy.sh   # asks for explicit confirmation
```
