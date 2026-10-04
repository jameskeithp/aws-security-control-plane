# ------------------------------------------------------------------------------
# lambda-remediation: the automated remediation engine. The deployment package
# is built from handler.py ONLY (boto3 ships in the Lambda runtime).
# ------------------------------------------------------------------------------

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../../../lambda/remediation/handler.py"
  output_path = "${path.module}/remediation.zip"
}

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-remediation-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-remediation-lambda"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_iam_role_policy" "lambda" {
  name = "${var.project_name}-${var.environment}-remediation-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      },
      {
        Sid    = "S3Remediation"
        Effect = "Allow"
        Action = [
          "s3:GetBucketTagging",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketEncryption",
          "s3:PutBucketEncryption",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
        ]
        Resource = "arn:aws:s3:::*"
      },
      {
        Sid      = "SecurityHubRead"
        Effect   = "Allow"
        Action   = ["securityhub:BatchGetFindings", "securityhub:GetFindings"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-remediation"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-remediation-logs"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_lambda_function" "remediation" {
  function_name    = "${var.project_name}-${var.environment}-remediation"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      DRY_RUN   = var.dry_run
      LOG_LEVEL = "INFO"
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-remediation"
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  depends_on = [aws_cloudwatch_log_group.lambda]
}
