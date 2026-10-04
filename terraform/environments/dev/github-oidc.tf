# ------------------------------------------------------------------------------
# GitHub OIDC: keyless CI/CD. GitHub Actions assumes this role with a short-
# lived OIDC token — no long-lived AWS access keys anywhere.
#
# Trust policy covers BOTH subject-claim formats:
#   1. Legacy:      token.actions.githubusercontent.com:sub = repo:org/repo:*
#   2. Post-July-2026 immutable format: repository + ref + sub conditions
# ------------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_actions_trust" {
  # Legacy subject format: repo:<org>/<repo>:*
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }

  # Post-July-2026 immutable subject format: repository + ref + sub conditions
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:repository"
      values   = ["${var.github_org}/${var.github_repo}"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:ref"
      values   = ["refs/heads/main"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-${var.environment}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-github-actions"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# Least-privilege deploy policy: exactly the services this stack manages.
resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "${var.project_name}-${var.environment}-deploy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket", "s3:DeleteBucket", "s3:Get*", "s3:List*",
          "s3:PutBucketPolicy", "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketVersioning", "s3:PutEncryptionConfiguration",
          "s3:PutBucketTagging", "s3:PutLifecycleConfiguration",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudTrail"
        Effect = "Allow"
        Action = [
          "cloudtrail:CreateTrail", "cloudtrail:DeleteTrail",
          "cloudtrail:UpdateTrail", "cloudtrail:GetTrail",
          "cloudtrail:DescribeTrails", "cloudtrail:StartLogging",
          "cloudtrail:StopLogging",
        ]
        Resource = "*"
      },
      {
        Sid    = "Config"
        Effect = "Allow"
        Action = [
          "config:PutConfigurationRecorder", "config:DeleteConfigurationRecorder",
          "config:DescribeConfigurationRecorders", "config:StartConfigurationRecorder",
          "config:StopConfigurationRecorder", "config:PutDeliveryChannel",
          "config:DeleteDeliveryChannel", "config:DescribeDeliveryChannels",
          "config:PutConfigRule", "config:DeleteConfigRule",
          "config:DescribeConfigRules",
        ]
        Resource = "*"
      },
      {
        Sid    = "DetectiveServices"
        Effect = "Allow"
        Action = [
          "guardduty:CreateDetector", "guardduty:DeleteDetector",
          "guardduty:GetDetector", "guardduty:UpdateDetector",
          "securityhub:EnableSecurityHub", "securityhub:DisableSecurityHub",
          "securityhub:BatchEnableStandards", "securityhub:DescribeHub",
          "macie2:EnableMacie", "macie2:DisableMacie", "macie2:GetMacieSession",
          "inspector2:Enable", "inspector2:Disable", "inspector2:BatchGetAccountStatus",
        ]
        Resource = "*"
      },
      {
        Sid    = "Lambda"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction", "lambda:DeleteFunction",
          "lambda:GetFunction", "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration", "lambda:AddPermission",
          "lambda:RemovePermission", "lambda:TagResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "EventBridgeAndLogs"
        Effect = "Allow"
        Action = [
          "events:PutRule", "events:DeleteRule", "events:DescribeRule",
          "events:PutTargets", "events:RemoveTargets", "events:TagResource",
          "logs:CreateLogGroup", "logs:DeleteLogGroup",
          "logs:DescribeLogGroups", "logs:PutRetentionPolicy",
          "logs:TagResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMForDeploy"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole",
          "iam:PassRole", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:TagRole",
          "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider", "iam:TagOpenIDConnectProvider",
        ]
        Resource = "*"
      },
    ]
  })
}
