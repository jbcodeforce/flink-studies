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
# Can use an existing role (via tableflow_iam_role_arn) or create a new one

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Confluent Cloud's AWS account ID (may vary by region, check Confluent docs)
# Common account ID: 197857026523
locals {
  confluent_cloud_account_id = "197857026523"
  
  # Determine S3 bucket name - use provided or created bucket
  tableflow_s3_bucket = var.tableflow_s3_bucket_name != "" ? var.tableflow_s3_bucket_name : aws_s3_bucket.card_tx_iceberg.bucket
  tableflow_s3_bucket_arn = var.tableflow_s3_bucket_name != "" ? "arn:aws:s3:::${var.tableflow_s3_bucket_name}" : aws_s3_bucket.card_tx_iceberg.arn
  
  # Determine Glue account ID - use provided or current account
  glue_account_id = var.tableflow_glue_account_id != "" ? var.tableflow_glue_account_id : data.aws_caller_identity.current.account_id
  
  # Determine which role ARN to use - existing or created
  tableflow_role_arn = var.tableflow_iam_role_arn != "" ? var.tableflow_iam_role_arn : aws_iam_role.confluent_tableflow_role[0].arn
}

# Data source for existing IAM role if provided
# Extract role name from ARN (format: arn:aws:iam::ACCOUNT:role/ROLE_NAME)
data "aws_iam_role" "existing_tableflow_role" {
  count = var.tableflow_iam_role_arn != "" ? 1 : 0
  name  = try(split("/", var.tableflow_iam_role_arn)[length(split("/", var.tableflow_iam_role_arn)) - 1], "")
}

# Create IAM role only if not using existing role
resource "aws_iam_role" "confluent_tableflow_role" {
  count = var.tableflow_iam_role_arn == "" ? 1 : 0
  name  = "${var.prefix}-confluent-tableflow-role-${random_id.env_display_id.hex}"

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

# Combined S3 and Glue policy
# If creating new role: attach policy with default name
# If using existing role: attach policy with specified name (or default if not specified)
locals {
  tableflow_policy_name = var.tableflow_iam_role_arn != "" ? (
    var.tableflow_iam_policy_name != "" ? var.tableflow_iam_policy_name : "${var.prefix}-tableflow-combined-policy"
  ) : "${var.prefix}-confluent-tableflow-combined-policy"
  
  tableflow_role_id = var.tableflow_iam_role_arn != "" ? data.aws_iam_role.existing_tableflow_role[0].id : aws_iam_role.confluent_tableflow_role[0].id
}

resource "aws_iam_role_policy" "confluent_tableflow_combined_policy" {
  name = local.tableflow_policy_name
  role = local.tableflow_role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets"
        ]
        Resource = [
          "arn:aws:s3:::*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads"
        ]
        Resource = [
          local.tableflow_s3_bucket_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:GetObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = [
          "${local.tableflow_s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetTable",
          "glue:GetDatabase",
          "glue:DeleteTable",
          "glue:DeleteDatabase",
          "glue:CreateTable",
          "glue:CreateDatabase",
          "glue:UpdateTable",
          "glue:UpdateDatabase"
        ]
        Resource = [
          "arn:aws:glue:${var.cloud_region}:${local.glue_account_id}:*"
        ]
      }
    ]
  })
}
