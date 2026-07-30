# -----------------------------------------------------------------------------
# AWS — dual-region S3 + Glue for Tableflow BYOB
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  confluent_cloud_account_id = "197857026523"
  tableflow_role_arn         = var.enable_tableflow ? aws_iam_role.tableflow[0].arn : ""
  primary_bucket_name        = "${var.prefix}-iceberg-primary-${random_id.suffix.hex}"
  dr_bucket_name             = "${var.prefix}-iceberg-dr-${random_id.suffix.hex}"
  glue_db_primary            = "dr_car_rides_primary"
  glue_db_dr                 = "dr_car_rides_dr"
}

# --- Primary region storage ---
resource "aws_s3_bucket" "iceberg_primary" {
  count    = var.enable_tableflow ? 1 : 0
  provider = aws.primary
  bucket   = local.primary_bucket_name
}

resource "aws_s3_bucket_versioning" "iceberg_primary" {
  count    = var.enable_tableflow ? 1 : 0
  provider = aws.primary
  bucket   = aws_s3_bucket.iceberg_primary[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "iceberg_primary" {
  count    = var.enable_tableflow ? 1 : 0
  provider = aws.primary
  bucket   = aws_s3_bucket.iceberg_primary[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_glue_catalog_database" "primary" {
  count       = var.enable_tableflow ? 1 : 0
  provider    = aws.primary
  name        = local.glue_db_primary
  description = "Glue catalog for DR car rides Tableflow (primary region)"
}

# --- DR region storage ---
resource "aws_s3_bucket" "iceberg_dr" {
  count    = var.enable_tableflow ? 1 : 0
  provider = aws.dr
  bucket   = local.dr_bucket_name
}

resource "aws_s3_bucket_versioning" "iceberg_dr" {
  count    = var.enable_tableflow ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.iceberg_dr[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "iceberg_dr" {
  count    = var.enable_tableflow ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.iceberg_dr[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_glue_catalog_database" "dr" {
  count       = var.enable_tableflow ? 1 : 0
  provider    = aws.dr
  name        = local.glue_db_dr
  description = "Glue catalog for DR car rides Tableflow (DR region)"
}

# --- IAM role for Confluent Tableflow (both buckets + Glue) ---
resource "aws_iam_role" "tableflow" {
  count = var.enable_tableflow ? 1 : 0
  name  = "${var.prefix}-tableflow-role-${random_id.suffix.hex}"

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
}

resource "aws_iam_role_policy" "tableflow_combined" {
  count = var.enable_tableflow ? 1 : 0
  name  = "${var.prefix}-tableflow-policy"
  role  = aws_iam_role.tableflow[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets"]
        Resource = ["arn:aws:s3:::*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads"
        ]
        Resource = [
          aws_s3_bucket.iceberg_primary[0].arn,
          aws_s3_bucket.iceberg_dr[0].arn,
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:GetObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.iceberg_primary[0].arn}/*",
          "${aws_s3_bucket.iceberg_dr[0].arn}/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetTable",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTables",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:CreateDatabase",
          "glue:UpdateDatabase",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition",
          "glue:BatchGetPartition",
          "glue:BatchUpdatePartition"
        ]
        Resource = [
          "arn:aws:glue:${var.primary_region}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${var.primary_region}:${data.aws_caller_identity.current.account_id}:database/${local.glue_db_primary}",
          "arn:aws:glue:${var.primary_region}:${data.aws_caller_identity.current.account_id}:table/${local.glue_db_primary}/*",
          "arn:aws:glue:${var.dr_region}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${var.dr_region}:${data.aws_caller_identity.current.account_id}:database/${local.glue_db_dr}",
          "arn:aws:glue:${var.dr_region}:${data.aws_caller_identity.current.account_id}:table/${local.glue_db_dr}/*",
        ]
      }
    ]
  })
}
