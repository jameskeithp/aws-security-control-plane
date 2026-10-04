#!/usr/bin/env python3
"""Automated remediation engine for AWS Security Hub S3 findings.

Triggered by EventBridge on ``Security Hub Findings - Imported`` events, this
Lambda inspects every ``AwsS3Bucket`` resource in FAILED findings and applies
preventive guardrails:

  * Block Public Access (all four flags)
  * Default server-side encryption (SSE-S3 / AES256)
  * Versioning enabled

Safety model:
  * DRY_RUN defaults to ``"true"`` — the engine only reports what it *would*
    change unless ``DRY_RUN=false`` is set explicitly.
  * Buckets tagged ``SecurityRemediation=disabled`` are excluded (break-glass).
  * Only allowlisted finding types are processed; anything else is skipped,
    never failed.
  * Remediation is idempotent: each control is read first and only changed
    when non-compliant, then re-read to verify (remediate -> verify flow).
  * All operational output is structured JSON logging.

The deployment package contains this file only (boto3 ships in the Lambda
Python runtime); see terraform/modules/lambda-remediation.
"""

from __future__ import annotations

import json
import logging
import os
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

LOG = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="%(message)s")

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

EXCEPTION_TAG_KEY = "SecurityRemediation"
EXCEPTION_TAG_VALUE = "disabled"

EVENT_SOURCE = "aws.securityhub"
EVENT_DETAIL_TYPE = "Security Hub Findings - Imported"

# Only findings from the AWS Security Best Practices standard are in scope.
SUPPORTED_FINDING_TYPE_PREFIX = "Software and Configuration Checks/AWS Security Best Practices"
SUPPORTED_RESOURCE_TYPE = "AwsS3Bucket"

PUBLIC_ACCESS_BLOCK_KEYS = (
    "BlockPublicAcls",
    "IgnorePublicAcls",
    "BlockPublicPolicy",
    "RestrictPublicBuckets",
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _utcnow_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def log_event(level: str, message: str, **fields) -> None:
    """Emit a single structured JSON log line."""
    record = {
        "timestamp": _utcnow_iso(),
        "level": level.upper(),
        "message": message,
    }
    record.update(fields)
    print(json.dumps(record, default=str))
    LOG.log(getattr(logging, level.upper(), logging.INFO), message)


def is_dry_run() -> bool:
    """DRY_RUN env var; defaults to True (report-only) when unset."""
    return os.environ.get("DRY_RUN", "true").strip().lower() in ("1", "true", "yes")


def parse_event(event: object) -> list[dict]:
    """Validate the EventBridge envelope and return its Security Hub findings.

    Raises:
        ValueError: if the event is not a Security Hub Findings - Imported
            event carrying at least one finding.
    """
    if not isinstance(event, dict):
        raise ValueError(f"event must be a dict, got {type(event).__name__}")
    if event.get("source") != EVENT_SOURCE:
        raise ValueError(f"unsupported event source: {event.get('source')!r}")
    if event.get("detail-type") != EVENT_DETAIL_TYPE:
        raise ValueError(f"unsupported detail-type: {event.get('detail-type')!r}")
    findings = (event.get("detail") or {}).get("findings") or []
    if not isinstance(findings, list) or not findings:
        raise ValueError("event carries no findings")
    return findings


def finding_targets(finding: dict) -> list[str]:
    """Return S3 bucket names this engine will remediate for one finding.

    Returns an empty list when the finding type is outside the allowlist or
    the finding references no AwsS3Bucket resources.
    """
    types = finding.get("Types") or []
    if not any(str(t).startswith(SUPPORTED_FINDING_TYPE_PREFIX) for t in types):
        return []
    buckets: list[str] = []
    for resource in finding.get("Resources") or []:
        if resource.get("Type") != SUPPORTED_RESOURCE_TYPE:
            continue
        resource_id = str(resource.get("Id", ""))
        buckets.append(resource_id.split(":::")[-1] if ":::" in resource_id else resource_id)
    return [b for b in buckets if b]


def has_exception_tag(s3_client, bucket: str) -> bool:
    """True when the bucket carries the SecurityRemediation=disabled tag."""
    try:
        tag_set = s3_client.get_bucket_tagging(Bucket=bucket).get("TagSet", [])
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") == "NoSuchTagSet":
            return False
        raise
    return any(
        tag.get("Key") == EXCEPTION_TAG_KEY and tag.get("Value") == EXCEPTION_TAG_VALUE
        for tag in tag_set
    )


def get_bucket_state(s3_client, bucket: str) -> dict:
    """Read the current guardrail state of a bucket (no mutations)."""
    state = {
        "public_access_blocked": False,
        "encryption_enabled": False,
        "versioning_enabled": False,
    }

    try:
        config = s3_client.get_public_access_block(Bucket=bucket)[
            "PublicAccessBlockConfiguration"
        ]
        state["public_access_blocked"] = all(
            bool(config.get(key)) for key in PUBLIC_ACCESS_BLOCK_KEYS
        )
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") != "NoSuchPublicAccessBlockConfiguration":
            raise

    try:
        rules = s3_client.get_bucket_encryption(Bucket=bucket)[
            "ServerSideEncryptionConfiguration"
        ]["Rules"]
        state["encryption_enabled"] = bool(rules)
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") != "ServerSideEncryptionConfigurationNotFoundError":
            raise

    versioning = s3_client.get_bucket_versioning(Bucket=bucket)
    state["versioning_enabled"] = versioning.get("Status") == "Enabled"

    return state


# --- per-control apply / verify -------------------------------------------

def _apply_public_access_block(s3_client, bucket: str) -> None:
    s3_client.put_public_access_block(
        Bucket=bucket,
        PublicAccessBlockConfiguration={key: True for key in PUBLIC_ACCESS_BLOCK_KEYS},
    )


def _apply_encryption(s3_client, bucket: str) -> None:
    s3_client.put_bucket_encryption(
        Bucket=bucket,
        ServerSideEncryptionConfiguration={
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"},
                    "BucketKeyEnabled": True,
                }
            ]
        },
    )


def _apply_versioning(s3_client, bucket: str) -> None:
    s3_client.put_bucket_versioning(
        Bucket=bucket,
        VersioningConfiguration={"Status": "Enabled"},
    )


_CONTROLS = (
    ("public_access_block", "public_access_blocked", _apply_public_access_block),
    ("encryption", "encryption_enabled", _apply_encryption),
    ("versioning", "versioning_enabled", _apply_versioning),
)


def remediate_bucket(s3_client, bucket: str, dry_run: bool = True) -> dict:
    """Idempotent remediate -> verify flow for a single bucket.

    Reads each control first; only non-compliant controls are changed, and each
    change is verified by re-reading afterwards. In dry-run mode nothing is
    mutated — controls are reported as ``would-change``.
    """
    if has_exception_tag(s3_client, bucket):
        log_event("INFO", "bucket excluded by exception tag", bucket=bucket)
        return {"bucket": bucket, "skipped": True, "reason": "exception-tag", "controls": []}

    state = get_bucket_state(s3_client, bucket)
    controls: list[dict] = []

    for control_name, state_key, apply_fn in _CONTROLS:
        if state[state_key]:
            controls.append({"control": control_name, "status": "already-compliant", "changed": False})
            continue
        if dry_run:
            controls.append({"control": control_name, "status": "would-change", "changed": False})
            log_event("INFO", "dry-run: would remediate control", bucket=bucket, control=control_name)
            continue
        apply_fn(s3_client, bucket)
        verified = get_bucket_state(s3_client, bucket)[state_key]
        status = "applied-verified" if verified else "applied-unverified"
        controls.append({"control": control_name, "status": status, "changed": True})
        log_event("INFO", "remediated control", bucket=bucket, control=control_name, status=status)

    return {"bucket": bucket, "skipped": False, "dry_run": dry_run, "controls": controls}


# ---------------------------------------------------------------------------
# Lambda entry point
# ---------------------------------------------------------------------------

def lambda_handler(event: dict, context) -> dict:  # noqa: ARG001 - Lambda signature
    """Process a Security Hub Findings - Imported EventBridge event."""
    try:
        findings = parse_event(event)
    except ValueError as exc:
        log_event("WARNING", "event rejected", error=str(exc))
        return {"statusCode": 400, "body": json.dumps({"error": str(exc)})}

    dry_run = is_dry_run()
    log_event(
        "INFO",
        "remediation run started",
        dry_run=dry_run,
        finding_count=len(findings),
    )

    s3 = boto3.client("s3")
    results: list[dict] = []

    for finding in findings:
        finding_id = finding.get("Id", "unknown")
        buckets = finding_targets(finding)
        if not buckets:
            log_event("INFO", "finding skipped (outside allowlist)", finding_id=finding_id)
            results.append({"finding_id": finding_id, "skipped": True, "reason": "not-in-allowlist"})
            continue
        for bucket in buckets:
            try:
                results.append(remediate_bucket(s3, bucket, dry_run=dry_run))
            except ClientError as exc:
                log_event("ERROR", "remediation failed", bucket=bucket, error=str(exc))
                results.append({"bucket": bucket, "skipped": True, "reason": "aws-error"})

    changed = sum(
        1
        for r in results
        for c in r.get("controls", [])
        if c.get("changed")
    )
    log_event("INFO", "remediation run finished", dry_run=dry_run, buckets_changed=changed)

    return {
        "statusCode": 200,
        "body": json.dumps({"dry_run": dry_run, "results": results}, default=str),
    }
