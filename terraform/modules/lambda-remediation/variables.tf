variable "project_name" {
  description = "Project prefix applied to resource names and tags."
  type        = string
}

variable "environment" {
  description = "Environment label (e.g. dev, staging, prod)."
  type        = string
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "dry_run" {
  description = "DRY_RUN env for the Lambda. \"true\" (default) only reports what would change; \"false\" applies remediations."
  type        = string
  default     = "true"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 180
}

variable "lambda_memory_size" {
  description = "Lambda memory in MB."
  type        = number
  default     = 256
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the Lambda log group."
  type        = number
  default     = 30
}
