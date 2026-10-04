# ------------------------------------------------------------------------------
# security-services: detective controls — GuardDuty, Security Hub (with
# security standards auto-enabled), Macie, and Inspector v2.
# ------------------------------------------------------------------------------

resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-guardduty"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_securityhub_account" "main" {
  # Boolean (not a list): enable the Security Hub security standards by default.
  auto_enable_controls = true
}

resource "aws_macie2_account" "main" {
  count = var.enable_macie ? 1 : 0

  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
}

resource "aws_inspector2_enabler" "main" {
  count = var.enable_inspector ? 1 : 0

  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["ECR", "EC2", "LAMBDA"]
}

data "aws_caller_identity" "current" {}
