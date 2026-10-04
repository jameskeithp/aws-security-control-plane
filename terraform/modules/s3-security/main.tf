# ------------------------------------------------------------------------------
# s3-security: hardened S3 bucket used for centralized security logs
# (CloudTrail + AWS Config delivery). Block Public Access, default SSE-S3,
# and versioning are enforced at creation.
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "logs" {
  bucket        = "${var.project_name}-${var.environment}-security-logs"
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-security-logs"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
