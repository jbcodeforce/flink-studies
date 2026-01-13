# -----------------------------------------------------------------------------
# AWS Infrastructure
# Card Transaction Processing Demo
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VPC Data Sources (Reusing Existing VPC)
# -----------------------------------------------------------------------------
data "aws_vpc" "existing" {
  id = var.existing_vpc_id
}

# Auto-discover subnets if not explicitly provided
data "aws_subnets" "existing" {
  filter {
    name   = "vpc-id"
    values = [var.existing_vpc_id]
  }
}

locals {
  subnet_ids = length(var.existing_subnet_ids) > 0 ? var.existing_subnet_ids : data.aws_subnets.existing.ids
}

# Get subnet details for the first subnet (for RDS)
data "aws_subnet" "primary" {
  id = local.subnet_ids[0]
}

# Get all subnet details for route table validation
data "aws_subnet" "all" {
  for_each = toset(local.subnet_ids)
  id       = each.value
}

# Find Internet Gateway in the VPC (optional - may not exist)
data "aws_internet_gateway" "vpc_igws" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

# Get route tables associated with each subnet
data "aws_route_tables" "subnet_route_tables" {
  for_each = toset(local.subnet_ids)
  filter {
    name   = "association.subnet-id"
    values = [each.value]
  }
}

# Get route table details to check for IGW routes
data "aws_route_table" "subnet_route_table" {
  for_each = {
    for subnet_id in local.subnet_ids : subnet_id => try(
      data.aws_route_tables.subnet_route_tables[subnet_id].ids[0],
      null
    )
    if length(data.aws_route_tables.subnet_route_tables[subnet_id].ids) > 0
  }
  route_table_id = each.value
}

# Validation: Ensure all RDS subnets have route tables with IGW routes
# This will fail during plan/apply if subnets don't have IGW routes
locals {
  # Get IGW ID if it exists
  vpc_igw_id = length(data.aws_internet_gateway.vpc_igws.id) > 0 ? data.aws_internet_gateway.vpc_igws.id : null
  
  # Check if each subnet's route table has a route to the IGW
  subnet_igw_validation = {
    for subnet_id in local.subnet_ids : subnet_id => {
      subnet_id      = subnet_id
      subnet_cidr    = data.aws_subnet.all[subnet_id].cidr_block
      route_table_id = try(
        data.aws_route_tables.subnet_route_tables[subnet_id].ids[0],
        "NO_ROUTE_TABLE"
      )
      has_route_table = length(data.aws_route_tables.subnet_route_tables[subnet_id].ids) > 0
      has_igw_route = local.vpc_igw_id != null && try(
        length([
          for route in data.aws_route_table.subnet_route_table[subnet_id].routes : route
          if route.gateway_id == local.vpc_igw_id && route.gateway_id != ""
        ]) > 0,
        false
      )
    }
  }
  
  # Collect subnets without IGW routes for error message
  subnets_without_igw = [
    for k, v in local.subnet_igw_validation : v
    if !v.has_igw_route || !v.has_route_table
  ]
}

# Validation check: Ensure all RDS subnets have IGW routes (only if publicly accessible)
# This will fail during terraform plan/apply if validation fails
check "rds_subnet_igw_validation" {
  # Only validate if RDS is configured to be publicly accessible
  assert {
    condition = !var.db_publicly_accessible || (
      local.vpc_igw_id != null && length(local.subnets_without_igw) == 0
    )
    error_message = <<-EOT
      ERROR: RDS is configured with db_publicly_accessible = true, but one or more RDS subnets 
      are not associated with route tables that have routes to an Internet Gateway.
      
      %{if local.vpc_igw_id == null~}
      No Internet Gateway found in VPC ${data.aws_vpc.existing.id}
      
      To fix: Create and attach an Internet Gateway to your VPC, then add routes to it in your route tables.
      %{else~}
      Subnets without IGW routes:
      %{for subnet in local.subnets_without_igw~}
      - Subnet ID: ${subnet.subnet_id} (CIDR: ${subnet.subnet_cidr})
        Route Table: ${subnet.route_table_id}
        Has Route Table: ${subnet.has_route_table}
        Has IGW Route: ${subnet.has_igw_route}
      %{endfor~}
      
      To fix this:
      1. Ensure each subnet is associated with a route table that has a route to the IGW
      2. Check route table associations:
         aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=<subnet-id>"
      3. Verify IGW routes exist:
         aws ec2 describe-route-tables --route-table-ids <route-table-id> \
           --query 'RouteTables[0].Routes[?GatewayId!=null]'
      4. If needed, associate subnets with the correct route table:
         aws ec2 associate-route-table --subnet-id <subnet-id> --route-table-id <route-table-id>
      5. Or add IGW route to the route table:
         aws ec2 create-route --route-table-id <route-table-id> \
           --destination-cidr-block 0.0.0.0/0 --gateway-id ${local.vpc_igw_id}
      %{endif~}
      
      Note: If db_publicly_accessible = true, RDS requires subnets with IGW routes.
      If you don't need public access, set db_publicly_accessible = false in terraform.tfvars.
    EOT
  }
}

# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------

# Security group for RDS PostgreSQL
resource "aws_security_group" "card_tx_db_sg" {
  name        = "${var.prefix}-db-sg-${random_id.env_display_id.hex}"
  description = "Security group for Card Transaction PostgreSQL database"
  vpc_id      = data.aws_vpc.existing.id

  tags = {
    Name = "${var.prefix}-db-sg"
  }
}

# Combine Confluent Cloud IPs with user-specified IPs
locals {
  # Combine all allowed CIDR blocks
  all_allowed_cidr_blocks = var.allow_all_cidr_blocks ? ["0.0.0.0/0"] : concat(
    var.confluent_cloud_cidr_blocks,
    var.db_allowed_cidr_blocks
  )
}

# Inbound rule for PostgreSQL
# Combines Confluent Cloud connector IPs with user-specified IPs
# Set allow_all_cidr_blocks = true only for testing (WARNING: insecure)
resource "aws_security_group_rule" "allow_inbound_postgres" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.card_tx_db_sg.id
  cidr_blocks       = local.all_allowed_cidr_blocks
  description       = "Allow PostgreSQL inbound traffic from Confluent Cloud connectors and specified IPs"
}

# Outbound rule for PostgreSQL
resource "aws_security_group_rule" "allow_outbound_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.card_tx_db_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
}

# -----------------------------------------------------------------------------
# RDS Subnet Group
# -----------------------------------------------------------------------------
# NOTE: This is NOT creating new subnets. RDS requires a DB subnet group
# which is just a logical grouping of existing subnets from your VPC.
# We're using the same subnets discovered from your existing VPC.
resource "aws_db_subnet_group" "card_tx_db_subnet_group" {
  name       = "${var.prefix}-db-subnet-group-${random_id.env_display_id.hex}"
  subnet_ids = local.subnet_ids  # Uses existing subnets from your VPC

  tags = {
    Name = "${var.prefix}-db-subnet-group"
  }
}

# -----------------------------------------------------------------------------
# RDS Parameter Group (Enable Logical Replication for Debezium CDC)
# -----------------------------------------------------------------------------
resource "aws_db_parameter_group" "card_tx_pg_params" {
  name   = "${var.prefix}-pg-debezium-${random_id.env_display_id.hex}"
  family = "postgres17"

  parameter {
    apply_method = "pending-reboot"
    name         = "rds.logical_replication"
    value        = "1"
  }

  tags = {
    Name = "${var.prefix}-pg-debezium-params"
  }
}

# -----------------------------------------------------------------------------
# RDS PostgreSQL Instance
# -----------------------------------------------------------------------------
resource "aws_db_instance" "card_tx_db" {
  identifier     = "${var.prefix}-db-${random_id.env_display_id.hex}"
  engine         = "postgres"
  engine_version = "17.4"
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"

  db_name  = "cardtxdb"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.card_tx_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.card_tx_db_sg.id]
  parameter_group_name   = aws_db_parameter_group.card_tx_pg_params.name

  publicly_accessible = var.db_publicly_accessible
  skip_final_snapshot = true
  apply_immediately   = true

  tags = {
    Name = "${var.prefix}-postgresql"
  }
}

# -----------------------------------------------------------------------------
# Create Database Tables
# -----------------------------------------------------------------------------
# NOTE: This requires 'psql' to be installed on the machine running Terraform.
# If psql is not available, set create_tables_automatically = false and run manually:
#   psql -h <rds-endpoint> -U postgres -d cardtxdb -f schema.sql
#
# To install psql:
#   macOS: brew install postgresql
#   Ubuntu/Debian: sudo apt-get install postgresql-client
#   RHEL/CentOS: sudo yum install postgresql
resource "null_resource" "create_tables" {
  count = var.create_tables_automatically ? 1 : 0

  depends_on = [aws_db_instance.card_tx_db]

  provisioner "local-exec" {
    command = <<-EOT
      if ! command -v psql &> /dev/null; then
        echo "ERROR: psql command not found. Please install PostgreSQL client tools."
        echo ""
        echo "Installation instructions:"
        echo "  macOS:    brew install postgresql"
        echo "  Ubuntu:   sudo apt-get install postgresql-client"
        echo "  RHEL:     sudo yum install postgresql"
        echo ""
        echo "Alternatively, set create_tables_automatically = false in terraform.tfvars"
        echo "and run the schema manually:"
        echo "  psql -h ${aws_db_instance.card_tx_db.address} -U ${var.db_username} -d ${aws_db_instance.card_tx_db.db_name} -f ${path.module}/schema.sql"
        exit 1
      fi
      
      PGPASSWORD=${var.db_password} psql \
        -h ${aws_db_instance.card_tx_db.address} \
        -p ${aws_db_instance.card_tx_db.port} \
        -U ${var.db_username} \
        -d ${aws_db_instance.card_tx_db.db_name} \
        -f ${path.module}/schema.sql
    EOT
  }

  triggers = {
    db_instance_id = aws_db_instance.card_tx_db.id
  }
}

# -----------------------------------------------------------------------------
# S3 Bucket for Iceberg Sink
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "card_tx_iceberg" {
  bucket = "${var.prefix}-iceberg-sink-${random_id.env_display_id.hex}"

  tags = {
    Name = "${var.prefix}-iceberg-sink"
  }
}

resource "aws_s3_bucket_versioning" "card_tx_iceberg_versioning" {
  bucket = aws_s3_bucket.card_tx_iceberg.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "card_tx_iceberg_encryption" {
  bucket = aws_s3_bucket.card_tx_iceberg.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
