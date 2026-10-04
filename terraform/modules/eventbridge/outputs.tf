output "rule_arn" {
  description = "ARN of the EventBridge rule routing Security Hub S3 findings."
  value       = aws_cloudwatch_event_rule.security_hub_s3.arn
}

output "rule_name" {
  description = "Name of the EventBridge rule."
  value       = aws_cloudwatch_event_rule.security_hub_s3.name
}
