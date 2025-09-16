# Generate a unique bucket name if not provided
locals {
  bucket_name = var.bucket_name != "" ? var.bucket_name : "${var.project_name}-confluent-s3-sink-${var.environment}-${random_id.bucket_suffix.hex}"
}

# Random ID for unique bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket for Confluent Cloud Sink Connector
resource "aws_s3_bucket" "confluent_sink" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = {
    Name        = local.bucket_name
    Purpose     = "Confluent Cloud S3 Sink Connector"
    Environment = var.environment
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "confluent_sink" {
  bucket = aws_s3_bucket.confluent_sink.id
  
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Disabled"
  }
}

# S3 Bucket Server-side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "confluent_sink" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.confluent_sink.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "confluent_sink" {
  count  = var.enable_public_access_block ? 1 : 0
  bucket = aws_s3_bucket.confluent_sink.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM User for Confluent Cloud Service Account
resource "aws_iam_user" "confluent_s3_user" {
  name = "${var.project_name}-confluent-s3-user-${var.environment}"
  path = "/"

  tags = {
    Name        = "${var.project_name}-confluent-s3-user-${var.environment}"
    Purpose     = "Confluent Cloud S3 Sink Connector Service Account"
    Environment = var.environment
  }
}

# IAM Policy for S3 Access
resource "aws_iam_policy" "confluent_s3_policy" {
  name        = "${var.project_name}-confluent-s3-policy-${var.environment}"
  description = "IAM policy for Confluent Cloud S3 Sink Connector"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.confluent_sink.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.confluent_sink.arn}/*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-confluent-s3-policy-${var.environment}"
    Purpose     = "Confluent Cloud S3 Sink Connector Policy"
    Environment = var.environment
  }
}

# Attach policy to user
resource "aws_iam_user_policy_attachment" "confluent_s3_user_policy" {
  user       = aws_iam_user.confluent_s3_user.name
  policy_arn = aws_iam_policy.confluent_s3_policy.arn
}

# IAM Access Key for programmatic access
resource "aws_iam_access_key" "confluent_s3_user_key" {
  user = aws_iam_user.confluent_s3_user.name
}
