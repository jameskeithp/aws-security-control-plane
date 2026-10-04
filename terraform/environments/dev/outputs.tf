output "account_id" {
  description = "AWS account ID the stack was deployed into."
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "AWS region of the deployment."
  value       = data.aws_region.current.name
}

output "logs_bucket_arn" {
  description = "ARN of the hardened security logs bucket."
  value       = module.s3_security.logs_bucket_arn
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail."
  value       = module.cloudtrail.trail_arn
}

output "config_recorder_name" {
  description = "Name of the AWS Config recorder."
  value       = module.config.recorder_name
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector."
  value       = module.security_services.guardduty_detector_id
}

output "lambda_function_arn" {
  description = "ARN of the remediation Lambda function."
  value       = module.lambda_remediation.function_arn
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule routing S3 findings to the Lambda."
  value       = module.eventbridge.rule_arn
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role GitHub Actions assumes via OIDC."
  value       = aws_iam_role.github_actions.arn
}
