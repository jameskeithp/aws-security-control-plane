"""Repository-level tests: validate example policies and test fixtures.

These tests guard the JSON documents shipped under policies/ and tests/ so
broken policy syntax is caught in CI before it ever reaches Terraform.
"""

import json
import os

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POLICIES_DIR = os.path.join(ROOT, "policies")
FIXTURES_DIR = os.path.join(ROOT, "tests", "fixtures")


def load_json(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


@pytest.mark.parametrize(
    "filename",
    ["s3-security.json", "iam-security.json", "network-security.json"],
)
def test_policies_are_valid_json(filename):
    doc = load_json(os.path.join(POLICIES_DIR, filename))
    assert isinstance(doc, dict)


def test_s3_policy_denies_unencrypted_and_insecure_transport():
    doc = load_json(os.path.join(POLICIES_DIR, "s3-security.json"))
    sids = {s["Sid"] for s in doc["Statement"]}
    assert "DenyUnencryptedObjectUploads" in sids
    assert "DenyInsecureTransport" in sids
    deny_transport = next(s for s in doc["Statement"] if s["Sid"] == "DenyInsecureTransport")
    assert deny_transport["Effect"] == "Deny"
    assert deny_transport["Condition"]["Bool"]["aws:SecureTransport"] == "false"


def test_iam_policy_denies_sensitive_actions_without_mfa():
    doc = load_json(os.path.join(POLICIES_DIR, "iam-security.json"))
    mfa_stmt = next(s for s in doc["Statement"] if s["Sid"] == "DenySensitiveActionsWithoutMFA")
    assert mfa_stmt["Effect"] == "Deny"
    assert "iam:CreateAccessKey" in mfa_stmt["Action"]


def test_securityhub_fixture_matches_eventbridge_contract():
    """The fixture must look like what the EventBridge rule actually routes."""
    event = load_json(os.path.join(FIXTURES_DIR, "securityhub-s3-finding.json"))
    assert event["source"] == "aws.securityhub"
    assert event["detail-type"] == "Security Hub Findings - Imported"
    findings = event["detail"]["findings"]
    assert len(findings) >= 1
    finding = findings[0]
    assert finding["Compliance"]["Status"] == "FAILED"
    assert finding["RecordState"] == "ACTIVE"
    resources = finding["Resources"]
    assert any(r["Type"] == "AwsS3Bucket" for r in resources)
    assert any(
        t.startswith("Software and Configuration Checks/AWS Security Best Practices")
        for t in finding["Types"]
    )
