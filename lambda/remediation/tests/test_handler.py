"""Unit tests for the S3 remediation Lambda (lambda/remediation/handler.py).

boto3 is stubbed when absent so the suite runs anywhere; the S3 client is
always replaced with a stateful mock, so no AWS credentials are needed.
"""

import json
import os
import sys
import types
from unittest import mock

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
LAMBDA_DIR = os.path.dirname(HERE)
sys.path.insert(0, LAMBDA_DIR)

# --- dependency guards (boto3/botocore ship in the Lambda runtime) ----------

try:
    import boto3  # noqa: F401
except ImportError:  # pragma: no cover - local-only fallback
    sys.modules["boto3"] = mock.MagicMock(name="boto3")

try:
    from botocore.exceptions import ClientError  # noqa: F401
except ImportError:  # pragma: no cover - local-only fallback
    _be = types.ModuleType("botocore.exceptions")

    class _ClientError(Exception):
        def __init__(self, error_response, operation_name):
            super().__init__(str(error_response))
            self.response = error_response
            self.operation_name = operation_name

    _be.ClientError = _ClientError
    _b = types.ModuleType("botocore")
    _b.exceptions = _be
    sys.modules["botocore"] = _b
    sys.modules["botocore.exceptions"] = _be
    ClientError = _ClientError

import handler  # noqa: E402


# --- helpers -----------------------------------------------------------------

PAB_KEYS = (
    "BlockPublicAcls",
    "IgnorePublicAcls",
    "BlockPublicPolicy",
    "RestrictPublicBuckets",
)


def make_s3(state, tags=None):
    """Stateful S3 mock: put_* calls mutate `state`, get_* calls read it."""
    s3 = mock.MagicMock(name="s3")

    def _pab(Bucket):
        if not state["public_access_blocked"]:
            raise ClientError(
                {"Error": {"Code": "NoSuchPublicAccessBlockConfiguration"}},
                "GetPublicAccessBlock",
            )
        return {"PublicAccessBlockConfiguration": {k: True for k in PAB_KEYS}}

    def _enc(Bucket):
        if not state["encryption_enabled"]:
            raise ClientError(
                {"Error": {"Code": "ServerSideEncryptionConfigurationNotFoundError"}},
                "GetBucketEncryption",
            )
        return {
            "ServerSideEncryptionConfiguration": {
                "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
            }
        }

    def _ver(Bucket):
        return {"Status": "Enabled" if state["versioning_enabled"] else "Suspended"}

    s3.get_public_access_block.side_effect = _pab
    s3.get_bucket_encryption.side_effect = _enc
    s3.get_bucket_versioning.side_effect = _ver
    s3.get_bucket_tagging.side_effect = lambda Bucket: {"TagSet": tags or []}

    def _put_pab(Bucket, PublicAccessBlockConfiguration):
        state["public_access_blocked"] = all(PublicAccessBlockConfiguration.values())

    def _put_enc(Bucket, ServerSideEncryptionConfiguration):
        state["encryption_enabled"] = True

    def _put_ver(Bucket, VersioningConfiguration):
        state["versioning_enabled"] = VersioningConfiguration.get("Status") == "Enabled"

    s3.put_public_access_block.side_effect = _put_pab
    s3.put_bucket_encryption.side_effect = _put_enc
    s3.put_bucket_versioning.side_effect = _put_ver
    return s3


def make_event(bucket="test-bucket", resource_type="AwsS3Bucket"):
    return {
        "version": "0",
        "id": "evt-1",
        "detail-type": "Security Hub Findings - Imported",
        "source": "aws.securityhub",
        "account": "000000000000",
        "region": "us-east-1",
        "detail": {
            "findings": [
                {
                    "Id": "finding-1",
                    "Title": "S3.1 S3 general purpose buckets should have block public access settings enabled",
                    "Types": ["Software and Configuration Checks/AWS Security Best Practices"],
                    "Compliance": {"Status": "FAILED"},
                    "Resources": [{"Type": resource_type, "Id": f"arn:aws:s3:::{bucket}"}],
                }
            ]
        },
    }


def run_handler(event, s3):
    with mock.patch.object(handler.boto3, "client", return_value=s3):
        return handler.lambda_handler(event, None)


# --- tests -------------------------------------------------------------------

def test_dry_run_defaults_to_true(monkeypatch):
    """DRY_RUN unset -> dry-run mode (safe default)."""
    monkeypatch.delenv("DRY_RUN", raising=False)
    assert handler.is_dry_run() is True
    monkeypatch.setenv("DRY_RUN", "false")
    assert handler.is_dry_run() is False


def test_rejects_non_securityhub_event():
    """Events outside the allowlist are rejected with 400, never processed."""
    s3 = make_s3({"public_access_blocked": False, "encryption_enabled": False, "versioning_enabled": False})
    result = run_handler({"source": "aws.ec2", "detail-type": "EC2 State Change"}, s3)
    assert result["statusCode"] == 400
    s3.put_public_access_block.assert_not_called()
    s3.put_bucket_encryption.assert_not_called()
    s3.put_bucket_versioning.assert_not_called()


def test_skips_unsupported_resource_type(monkeypatch):
    """Findings without AwsS3Bucket resources are skipped, not failed."""
    monkeypatch.setenv("DRY_RUN", "true")
    s3 = make_s3({"public_access_blocked": False, "encryption_enabled": False, "versioning_enabled": False})
    result = run_handler(make_event(resource_type="AwsEc2Instance"), s3)
    body = json.loads(result["body"])
    assert result["statusCode"] == 200
    assert body["results"][0]["skipped"] is True
    s3.put_public_access_block.assert_not_called()


def test_exception_tag_skips_bucket(monkeypatch):
    """Buckets tagged SecurityRemediation=disabled are left untouched."""
    monkeypatch.setenv("DRY_RUN", "false")
    tags = [{"Key": "SecurityRemediation", "Value": "disabled"}]
    s3 = make_s3(
        {"public_access_blocked": False, "encryption_enabled": False, "versioning_enabled": False},
        tags=tags,
    )
    result = run_handler(make_event(), s3)
    body = json.loads(result["body"])
    bucket_result = body["results"][0]
    assert bucket_result["skipped"] is True
    assert bucket_result["reason"] == "exception-tag"
    s3.put_public_access_block.assert_not_called()
    s3.put_bucket_encryption.assert_not_called()
    s3.put_bucket_versioning.assert_not_called()


def test_live_remediation_applies_and_verifies(monkeypatch):
    """DRY_RUN=false on a non-compliant bucket: all three controls applied and verified."""
    monkeypatch.setenv("DRY_RUN", "false")
    s3 = make_s3({"public_access_blocked": False, "encryption_enabled": False, "versioning_enabled": False})
    result = run_handler(make_event(), s3)
    body = json.loads(result["body"])
    assert body["dry_run"] is False
    controls = {c["control"]: c for c in body["results"][0]["controls"]}
    assert set(controls) == {"public_access_block", "encryption", "versioning"}
    for control in controls.values():
        assert control["status"] == "applied-verified"
        assert control["changed"] is True
    s3.put_public_access_block.assert_called_once()
    s3.put_bucket_encryption.assert_called_once()
    s3.put_bucket_versioning.assert_called_once()


def test_idempotent_when_already_compliant(monkeypatch):
    """A compliant bucket triggers zero mutations (idempotent no-op)."""
    monkeypatch.setenv("DRY_RUN", "false")
    s3 = make_s3({"public_access_blocked": True, "encryption_enabled": True, "versioning_enabled": True})
    result = run_handler(make_event(), s3)
    body = json.loads(result["body"])
    controls = {c["control"]: c for c in body["results"][0]["controls"]}
    for control in controls.values():
        assert control["status"] == "already-compliant"
        assert control["changed"] is False
    s3.put_public_access_block.assert_not_called()
    s3.put_bucket_encryption.assert_not_called()
    s3.put_bucket_versioning.assert_not_called()
