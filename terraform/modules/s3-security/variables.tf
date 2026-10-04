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

variable "force_destroy" {
  description = "Allow the logs bucket to be destroyed even when it contains objects. Keep false in production."
  type        = bool
  default     = false
}
