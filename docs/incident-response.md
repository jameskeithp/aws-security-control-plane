# Incident Response Runbook — S3 Findings

Playbook for responding when Security Hub (or the remediation Lambda) flags
an S3 bucket. Follow your organization's IR plan; this runbook covers the
technical steps specific to this control plane.

## Severity Guide

| Severity | Example | Response |
| -------- | ------- | -------- |
| Critical | Public bucket with sensitive data (PII/PHI) | Immediate containment |
| High | Public bucket, no sensitive data confirmed | Contain within 1 hour |
| Medium | Missing encryption/versioning | Remediate within 24 hours |

## 1. Triage (first 15 minutes)

1. Open the Security Hub finding; note the bucket, region, and control (e.g. S3.1).
2. Check CloudTrail (`eventName=PutBucketPolicy`, `PutPublicAccessBlock`) for
   who/what changed the bucket recently:
   - CloudTrail Lake query: `SELECT * FROM <event-data-store> WHERE
     requestParameters.bucketName = '<bucket>' ORDER BY eventTime DESC LIMIT 50`
3. Check Macie/GuardDuty for related findings on the same bucket.

## 2. Contain

- If the bucket is public and should not be: the remediation Lambda has
  likely already applied the public-access block (check its CloudWatch Logs
  for `applied-verified`). If dry-run is on, apply manually:
  `aws s3api put-public-access-block --bucket <bucket> \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true`
- Rotate any credentials that may have been exposed; treat exposed data as
  compromised until proven otherwise.

## 3. Eradicate & Recover

- Remove unintended bucket policies/ACLs; restore the baseline (encryption,
  versioning, Block Public Access).
- If data was exfiltrated, engage legal/compliance before deleting logs.

## 4. Lessons Learned (within 5 business days)

- Why did the control drift? (manual change, IaC drift, new bucket without baseline?)
- Add a preventive control: Service Control Policy, or extend the
  `s3-security` module to cover the bucket's account.
- Record evidence per [evidence.md](evidence.md).

## Escalation

| Condition | Escalate to |
| --------- | ----------- |
| Suspected data exfiltration | Security leadership + legal |
| Finding in a production account | On-call engineer immediately |
| Repeat findings on the same bucket | Bucket owner + architecture review |
