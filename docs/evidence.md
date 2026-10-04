# Evidence Collection

What to collect, and where, when you need to prove a control is working
(audit, incident review, or compliance assessment).

## Evidence Sources

| Control claim | Evidence | Where to find it |
| ------------- | -------- | ---------------- |
| S3 buckets hardened | `aws s3api get-public-access-block`, `get-bucket-encryption`, `get-bucket-versioning` per bucket | AWS CLI / Config rule evaluations |
| No unencrypted uploads | S3 access logs / CloudTrail `PutObject` events with `s3:x-amz-server-side-encryption` | CloudTrail Lake |
| Trail integrity | CloudTrail digest files + `enable_log_file_validation` | `s3://<logs-bucket>/cloudtrail/.../digest/` |
| Config compliance | Config rule evaluation history | Config console / `aws configservice get-compliance-details-by-config-rule` |
| Findings triaged | Security Hub finding history + workflow status | Security Hub console |
| Remediation ran | Lambda CloudWatch Logs (JSON lines with `applied-verified`) | `/aws/lambda/<project>-<env>-remediation` |
| Deploys were keyless | GitHub Actions workflow runs (OIDC) + CloudTrail `AssumeRoleWithWebIdentity` | GitHub + CloudTrail |
| Code scanned | Trivy workflow runs and SARIF/output | GitHub Actions `security.yml` runs |

## Useful Queries

**CloudTrail Lake — who touched a bucket's policy (last 30 days):**

```sql
SELECT eventTime, userIdentity.arn, eventName, errorCode
FROM <event-data-store-id>
WHERE eventName IN ('PutBucketPolicy', 'PutPublicAccessBlock', 'PutBucketAcl')
  AND requestParameters.bucketName = '<bucket-name>'
ORDER BY eventTime DESC
LIMIT 100
```

**CloudWatch Logs Insights — remediation outcomes:**

```
fields @timestamp, bucket, control, status
| filter message = "remediated control"
| stats count() by control, status
```

**Config — non-compliant S3 buckets right now:**

```bash
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name s3-bucket-public-read-prohibited \
  --compliance-types NON_COMPLIANT
```

## Retention

- CloudTrail logs: versioned, lifecycle-expire noncurrent versions after 90 days
  (`s3-security` module); extend retention for regulated workloads.
- Lambda logs: 30 days (`log_retention_days`); raise for audit-heavy environments.
- Keep exported evidence (CSVs, screenshots, finding exports) with the audit
  workpapers, not in this repository.
