# NIST Mapping

How this control plane maps to the NIST Cybersecurity Framework (CSF) 2.0
functions and NIST SP 800-53 Rev. 5 controls.

## CSF 2.0 Mapping

| CSF Function / Category | Control-plane implementation |
| ----------------------- | ---------------------------- |
| Govern (GV.OC-01, GV.RM-01) | `docs/` runbooks; `SECURITY.md` reporting policy; least-privilege OIDC deploy role |
| Identify (ID.AM-01, ID.RA-01) | AWS Config inventory; Macie data classification; Inspector exposure assessment |
| Protect (PR.AC-01, PR.AC-04) | IAM least-privilege roles; OIDC (no static keys); S3 Block Public Access + bucket policies (`policies/`) |
| Protect (PR.DS-01, PR.DS-02) | S3 default encryption (SSE-S3); versioning; TLS-only bucket policies |
| Detect (DE.CM-01, DE.CM-02) | GuardDuty; Security Hub aggregated findings; Macie; Config rules |
| Respond (RS.MA-01, RS.AN-01) | Lambda remediation engine (auto-contain S3 drift); [incident-response.md](incident-response.md) |
| Recover (RC.RP-01) | S3 versioning; CloudTrail + Config history for forensics |

## SP 800-53 Rev. 5 Mapping (selected)

| Control | Name | Implementation |
| ------- | ---- | -------------- |
| AC-3 | Access Enforcement | S3 bucket policies; IAM least-privilege roles |
| AC-6 | Least Privilege | Scoped Lambda execution role; scoped GitHub deploy role |
| AU-2, AU-3, AU-9 | Audit events / content / protection | Multi-region CloudTrail w/ log-file validation to hardened bucket |
| CM-2, CM-8 | Baselines / inventory | Terraform-defined baseline; Config recorder inventory |
| IA-2 | Identification & Authentication | OIDC federation for CI/CD (no long-lived credentials) |
| SC-7 | Boundary Protection | Public-access blocks; `policies/network-security.json` requirements |
| SC-12, SC-28 | Crypto key establishment / protection at rest | SSE-S3 default encryption on all managed buckets |
| SI-4 | System Monitoring | GuardDuty + Security Hub + Macie + Inspector |
| SI-7 | Software/Firmware Integrity | Trivy scans in CI (`security.yml`); versioned Lambda packaging |
| IR-4 | Incident Handling | [incident-response.md](incident-response.md) runbook |

## Notes for Assessors

- The `dev` environment is a reference implementation. Control inheritance
  (e.g., AWS-managed physical controls) is out of scope for this mapping.
- Evidence artifacts supporting each row are described in
  [evidence.md](evidence.md).
