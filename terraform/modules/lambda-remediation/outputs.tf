output "function_arn" {
  description = "ARN of the remediation Lambda function."
  value       = aws_lambda_function.remediation.arn
}

output "function_name" {
  description = "Name of the remediation Lambda function."
  value       = aws_lambda_function.remediation.function_name
}

output "role_arn" {
  description = "ARN of the Lambda execution role."
  value       = aws_iam_role.lambda.arn
}
