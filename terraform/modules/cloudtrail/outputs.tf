output "trail_arn" {
  description = "ARN of the CloudTrail trail."
  value       = aws_cloudtrail.main.arn
}

output "trail_name" {
  description = "Name of the CloudTrail trail."
  value       = aws_cloudtrail.main.name
}
