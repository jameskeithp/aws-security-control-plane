variable "project_name" {
  description = "Project prefix applied to resource names and tags."
  type        = string
}

variable "environment" {
  description = "Environment label (e.g. dev, staging, prod)."
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN of the remediation Lambda function (event target)."
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the remediation Lambda function (for the invoke permission)."
  type        = string
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
