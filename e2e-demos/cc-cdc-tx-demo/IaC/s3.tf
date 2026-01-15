# -----------------------------------------------------------------------------
# S3 Infrastructure
# Card Transaction Processing Demo
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# S3 Bucket for Iceberg Sink
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "card_tx_iceberg" {
  bucket = "${var.prefix}-iceberg-sink-${random_id.env_display_id.hex}"

  tags = {
    Name = "${var.prefix}-iceberg-sink"
  }
}

# -----------------------------------------------------------------------------
# S3 Bucket Versioning
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "card_tx_iceberg_versioning" {
  bucket = aws_s3_bucket.card_tx_iceberg.id
  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------------------------------------------------------
# S3 Bucket Encryption
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "card_tx_iceberg_encryption" {
  bucket = aws_s3_bucket.card_tx_iceberg.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# -----------------------------------------------------------------------------
# IAM User and Access Key for S3 Sink Connector
# -----------------------------------------------------------------------------
resource "aws_iam_user" "s3_sink_user" {
  name = "${var.prefix}-s3-sink-user-${random_id.env_display_id.hex}"

  tags = {
    Name = "${var.prefix}-s3-sink-user"
  }
}

resource "aws_iam_access_key" "s3_sink_access_key" {
  user = aws_iam_user.s3_sink_user.name
}

resource "aws_iam_user_policy" "s3_sink_policy" {
  name = "${var.prefix}-s3-sink-policy"
  user = aws_iam_user.s3_sink_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.card_tx_iceberg.arn,
          "${aws_s3_bucket.card_tx_iceberg.arn}/*"
        ]
      }
    ]
  })
}


# -----------------------------------------------------------------------------
# IAM Role for Confluent Cloud Provider Integration
# -----------------------------------------------------------------------------
# This role allows Confluent Cloud to assume it for Tableflow BYOB access
# NOTE: After creating the provider integration, update this role's trust policy
# with the external_id from the provider integration output.

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Confluent Cloud's AWS account ID (may vary by region, check Confluent docs)
# Common account ID: 197857026523
locals {
  confluent_cloud_account_id = "197857026523"
}

resource "aws_iam_role" "confluent_tableflow_role" {
  name = "${var.prefix}-confluent-tableflow-role-${random_id.env_display_id.hex}"

  # Trust policy: Allow Confluent Cloud to assume this role
  # The external_id will be provided by Confluent Cloud when creating the provider integration
  # If external_id is provided via variable, use it; otherwise use a placeholder that needs manual update
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.confluent_cloud_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = var.confluent_external_id != "" ? {
          StringEquals = {
            "sts:ExternalId" = var.confluent_external_id
          }
        } : {}
      }
    ]
  })

  tags = {
    Name = "${var.prefix}-confluent-tableflow-role"
  }
}

resource "aws_iam_role_policy" "confluent_tableflow_s3_policy" {
  name = "${var.prefix}-confluent-tableflow-s3-policy"
  role = aws_iam_role.confluent_tableflow_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads",
          "s3:ListBucket",
          "s3:PutObjectTagging",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = [
          aws_s3_bucket.card_tx_iceberg.arn,
          "${aws_s3_bucket.card_tx_iceberg.arn}/*"
        ]
      }
    ]
  })
}
