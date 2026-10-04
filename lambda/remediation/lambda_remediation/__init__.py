"""Local wrapper package exposing the remediation Lambda handler.

The deployed Lambda package contains ``handler.py`` only (boto3 ships in the
Lambda Python runtime). This package exists so local tooling and tests can
``from lambda_remediation import lambda_handler`` without fiddling with
``sys.path`` themselves.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from handler import (  # noqa: E402
    EXCEPTION_TAG_KEY,
    EXCEPTION_TAG_VALUE,
    SUPPORTED_RESOURCE_TYPE,
    finding_targets,
    get_bucket_state,
    has_exception_tag,
    is_dry_run,
    lambda_handler,
    log_event,
    parse_event,
    remediate_bucket,
)

__all__ = [
    "EXCEPTION_TAG_KEY",
    "EXCEPTION_TAG_VALUE",
    "SUPPORTED_RESOURCE_TYPE",
    "finding_targets",
    "get_bucket_state",
    "has_exception_tag",
    "is_dry_run",
    "lambda_handler",
    "log_event",
    "parse_event",
    "remediate_bucket",
]
