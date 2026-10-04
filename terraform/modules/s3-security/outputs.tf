output "logs_bucket_id" {
  description = "Name (ID) of the hardened security logs bucket."
  value       = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  description = "ARN of the hardened security logs bucket."
  value       = aws_s3_bucket.logs.arn
}
