# ------------------------------------------------------------------------------
# config: AWS Config recorder + delivery channel + managed compliance rules.
# Snapshots and history are delivered to the hardened logs bucket.
# ------------------------------------------------------------------------------

resource "aws_iam_role" "config_recorder" {
  name = "${var.project_name}-${var.environment}-config-recorder"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-config-recorder"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_iam_role_policy_attachment" "config_recorder" {
  role       = aws_iam_role.config_recorder.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project_name}-${var.environment}-recorder"
  role_arn = aws_iam_role.config_recorder.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "${var.project_name}-${var.environment}-delivery"
  s3_bucket_name = var.logs_bucket_id
  s3_key_prefix  = "config"

  snapshot_delivery_properties {
    delivery_frequency = "Six_Hours"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# --- Managed rules: S3 and CloudTrail hygiene --------------------------------

resource "aws_config_config_rule" "s3_public_read_prohibited" {
  name = "s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

resource "aws_config_config_rule" "s3_public_write_prohibited" {
  name = "s3-bucket-public-write-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

resource "aws_config_config_rule" "s3_encryption_enabled" {
  name = "s3-bucket-server-side-encryption-enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

resource "aws_config_config_rule" "s3_versioning_enabled" {
  name = "s3-bucket-versioning-enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_VERSIONING_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

resource "aws_config_config_rule" "cloudtrail_enabled" {
  name = "cloudtrail-enabled"

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}
