# -----------------------------------------------------------------------------
# Redshift Serverless Configuration (Optional)
# Card Transaction Processing Demo
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Redshift Serverless Namespace
# -----------------------------------------------------------------------------
resource "aws_redshiftserverless_namespace" "card_tx_namespace" {
  count = var.enable_redshift ? 1 : 0

  namespace_name      = "${var.prefix}-namespace-${random_id.env_display_id.hex}"
  admin_username      = "admin"
  admin_user_password = var.db_password  # Reusing DB password for simplicity
  db_name             = "cardtxdw"

  iam_roles = [aws_iam_role.redshift_spectrum_role[0].arn]

  tags = {
    Name = "${var.prefix}-redshift-namespace"
  }
}

# -----------------------------------------------------------------------------
# Redshift Serverless Workgroup
# -----------------------------------------------------------------------------
resource "aws_redshiftserverless_workgroup" "card_tx_workgroup" {
  count = var.enable_redshift ? 1 : 0

  workgroup_name = "${var.prefix}-workgroup-${random_id.env_display_id.hex}"
  namespace_name = aws_redshiftserverless_namespace.card_tx_namespace[0].namespace_name
  base_capacity  = 32  # RPUs (Redshift Processing Units)

  subnet_ids         = local.subnet_ids
  security_group_ids = [aws_security_group.card_tx_redshift_sg[0].id]

  publicly_accessible = true

  tags = {
    Name = "${var.prefix}-redshift-workgroup"
  }
}

# -----------------------------------------------------------------------------
# Security Group for Redshift
# -----------------------------------------------------------------------------
resource "aws_security_group" "card_tx_redshift_sg" {
  count = var.enable_redshift ? 1 : 0

  name        = "${var.prefix}-redshift-sg-${random_id.env_display_id.hex}"
  description = "Security group for Card TX Redshift Serverless"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Redshift port"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.prefix}-redshift-sg"
  }
}

# -----------------------------------------------------------------------------
# IAM Role for Redshift Spectrum (S3 access)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "redshift_spectrum_role" {
  count = var.enable_redshift ? 1 : 0

  name = "${var.prefix}-redshift-spectrum-role-${random_id.env_display_id.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.prefix}-redshift-spectrum-role"
  }
}

resource "aws_iam_role_policy" "redshift_spectrum_s3_policy" {
  count = var.enable_redshift ? 1 : 0

  name = "${var.prefix}-redshift-spectrum-s3-policy"
  role = aws_iam_role.redshift_spectrum_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.card_tx_iceberg.arn,
          "${aws_s3_bucket.card_tx_iceberg.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "redshift_spectrum_glue_policy" {
  count = var.enable_redshift ? 1 : 0

  role       = aws_iam_role.redshift_spectrum_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"
}
