# ------------------------------------------------------------------------------
# eventbridge: route FAILED Security Hub findings for S3 buckets to the
# remediation Lambda.
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "security_hub_s3" {
  name        = "${var.project_name}-${var.environment}-securityhub-s3"
  description = "Route ACTIVE, FAILED Security Hub findings for S3 buckets to the remediation Lambda."

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        RecordState = ["ACTIVE"]
        Compliance = {
          Status = ["FAILED"]
        }
        Resources = {
          Type = ["AwsS3Bucket"]
        }
      }
    }
  })

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-securityhub-s3"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.security_hub_s3.name
  target_id = "remediation-lambda"
  arn       = var.lambda_function_arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.security_hub_s3.arn
}
