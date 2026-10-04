# ------------------------------------------------------------------------------
# dev environment: wires all control-plane modules together.
# ------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.tags, {
      Environment = var.environment
    })
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "s3_security" {
  source = "../../modules/s3-security"

  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
}

module "cloudtrail" {
  source = "../../modules/cloudtrail"

  project_name   = var.project_name
  environment    = var.environment
  logs_bucket_id = module.s3_security.logs_bucket_id
  tags           = var.tags
}

module "config" {
  source = "../../modules/config"

  project_name   = var.project_name
  environment    = var.environment
  logs_bucket_id = module.s3_security.logs_bucket_id
  tags           = var.tags
}

module "security_services" {
  source = "../../modules/security-services"

  project_name     = var.project_name
  environment      = var.environment
  tags             = var.tags
  enable_macie     = var.enable_macie
  enable_inspector = var.enable_inspector
}

module "lambda_remediation" {
  source = "../../modules/lambda-remediation"

  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
  dry_run      = var.dry_run
}

module "eventbridge" {
  source = "../../modules/eventbridge"

  project_name         = var.project_name
  environment          = var.environment
  tags                 = var.tags
  lambda_function_arn  = module.lambda_remediation.function_arn
  lambda_function_name = module.lambda_remediation.function_name
}
