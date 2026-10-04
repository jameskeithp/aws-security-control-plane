variable "project_name" {
  description = "Project prefix applied to resource names and tags."
  type        = string
}

variable "environment" {
  description = "Environment label (e.g. dev, staging, prod)."
  type        = string
}

variable "logs_bucket_id" {
  description = "ID (name) of the hardened S3 bucket that receives CloudTrail logs."
  type        = string
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
