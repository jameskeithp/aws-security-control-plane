# ------------------------------------------------------------------------------
# cloudtrail: multi-region organization-style trail with log-file validation,
# delivered to the hardened logs bucket created by the s3-security module.
# ------------------------------------------------------------------------------

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = var.logs_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = "arn:aws:s3:::${var.logs_bucket_id}"
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "arn:aws:s3:::${var.logs_bucket_id}/cloudtrail/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-${var.environment}-trail"
  s3_bucket_name                = var.logs_bucket_id
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation   = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-trail"
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}
