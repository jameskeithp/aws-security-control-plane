variable "project_name" {
  description = "Project prefix applied to resource names and tags."
  type        = string
  default     = "aws-security-control-plane"
}

variable "environment" {
  description = "Environment label."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "github_org" {
  description = "GitHub organization or user that owns the repository (for the OIDC trust policy)."
  type        = string
  default     = "jameskeithp"
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the deploy role via OIDC."
  type        = string
  default     = "aws-security-control-plane"
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default = {
    Project   = "aws-security-control-plane"
    ManagedBy = "terraform"
  }
}

variable "dry_run" {
  description = "DRY_RUN env for the remediation Lambda (\"true\" reports only; \"false\" applies changes)."
  type        = string
  default     = "true"
}

variable "enable_macie" {
  description = "Enable Amazon Macie."
  type        = bool
  default     = true
}

variable "enable_inspector" {
  description = "Enable Amazon Inspector v2."
  type        = bool
  default     = true
}
