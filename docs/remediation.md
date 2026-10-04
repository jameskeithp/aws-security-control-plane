# Remediation Engine

How the Lambda remediation engine (`lambda/remediation/handler.py`) works,
and how to operate it safely.

## Event Flow

```
Security Hub finding (FAILED, ACTIVE, AwsS3Bucket)
        │
        ▼
EventBridge rule: source=aws.securityhub,
  detail-type="Security Hub Findings - Imported",
  findings.RecordState=ACTIVE, Compliance.Status=FAILED,
  Resources.Type=AwsS3Bucket
        │
        ▼
Lambda: validate → allowlist → exception-tag check →
        remediate → verify → structured log
```

## Processing Stages

1. **Event validation** (`parse_event`) — rejects anything that is not a
   `Security Hub Findings - Imported` event carrying findings (HTTP 400-style
   response, no exception thrown to EventBridge).
2. **Allowlist** (`finding_targets`) — only findings from the *AWS Security
   Best Practices* standard referencing `AwsS3Bucket` resources are processed.
   Everything else is recorded as `skipped: not-in-allowlist`.
3. **Exception tag** (`has_exception_tag`) — buckets tagged
   `SecurityRemediation=disabled` are skipped. Use this for break-glass or
   intentionally-public buckets (e.g., static website hosting) after risk
   acceptance.
4. **Dry-run gate** (`is_dry_run`) — `DRY_RUN` env defaults to `"true"`.
   Dry-run reports `would-change` per control and makes zero AWS mutations.
5. **Remediate → verify** (`remediate_bucket`) — each control is read first;
   only non-compliant controls are changed, then re-read to confirm. Statuses:
   `already-compliant`, `would-change`, `applied-verified`, `applied-unverified`.

## Guardrails Applied

| Control | API call | Desired state |
| ------- | -------- | ------------- |
| Public access | `PutPublicAccessBlock` | All four block flags `true` |
| Encryption | `PutBucketEncryption` | SSE-S3 (AES256) default |
| Versioning | `PutBucketVersioning` | `Enabled` |

The engine never deletes buckets or objects and never loosens a control.

## Operating the Engine

- **Observe first:** deploy with `dry_run = "true"` and watch CloudWatch Logs
  for `would-change` entries to see the blast radius.
- **Go live:** set `dry_run = "false"` in `terraform.tfvars`, `terraform apply`,
  and monitor the first live runs closely.
- **Exclude a bucket:** `aws s3api put-bucket-tagging --bucket NAME \
  --tagging 'TagSet=[{Key=SecurityRemediation,Value=disabled}]'`
- **Logs:** every run emits JSON lines with `timestamp`, `level`, `message`,
  `bucket`, `control`, and `status` fields — ready for CloudWatch Insights.

## Testing

```bash
python -m pytest lambda/remediation/tests -v   # 6 unit tests, mocked S3
```

The suite covers: dry-run default, event rejection, allowlist skips,
exception-tag skips, live apply+verify, and idempotent no-ops.
