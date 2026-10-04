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

variable "enable_macie" {
  description = "Enable Amazon Macie for S3 data classification."
  type        = bool
  default     = true
}

variable "enable_inspector" {
  description = "Enable Amazon Inspector v2 for ECR, EC2, and Lambda scanning."
  type        = bool
  default     = true
}
