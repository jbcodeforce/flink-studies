# -----------------------------------------------------------------------------
# Variables Configuration
# Card Transaction Processing Demo
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# General Settings
# -----------------------------------------------------------------------------
variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "card-tx"
}

variable "owner_email" {
  description = "Email of the resource owner for tagging"
  type        = string
}

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------
variable "cloud_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-2"
}

variable "existing_vpc_id" {
  description = "ID of existing VPC to deploy into"
  type        = string
}

variable "existing_subnet_ids" {
  description = "List of existing subnet IDs in the VPC (optional - will auto-discover if not provided)"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# RDS PostgreSQL Configuration
# -----------------------------------------------------------------------------
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 100
}

variable "db_username" {
  description = "PostgreSQL database username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "PostgreSQL database password"
  type        = string
  sensitive   = true
}

variable "db_publicly_accessible" {
  description = "Whether the RDS instance should be publicly accessible"
  type        = bool
  default     = true
}

variable "create_tables_automatically" {
  description = "Whether to automatically create database tables using psql (requires psql to be installed)"
  type        = bool
  default     = true
}

variable "db_allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access RDS (in addition to Confluent Cloud IPs). For production, restrict to specific IPs."
  type        = list(string)
  default     = []
}

variable "confluent_cloud_cidr_blocks" {
  description = <<-EOT
    List of Confluent Cloud IP addresses/CIDR blocks for CDC connector access to RDS.
    These are the egress IPs from Confluent Cloud connectors.
    
    IMPORTANT: Update this list with the latest IPs from:
    - Confluent Cloud UI: Connectors → Your Connector → Networking
    - Confluent Cloud documentation: https://docs.confluent.io/cloud/current/networking/ip-ranges.html
    
    The default list includes common Confluent Cloud connector egress IPs.
    You should verify and update this list for your specific Confluent Cloud environment.
  EOT
  type        = list(string)
  default = [
    # Confluent Cloud connector egress IPs (common ranges)
    # Update with your specific Confluent Cloud environment IPs
    "35.80.209.50/32",
    "35.81.13.52/32",
    "35.83.49.171/32",
    "35.161.10.145/32",
    "35.161.229.13/32",
    "35.163.98.130/32",
    "44.224.191.248/32",
    "44.226.85.132/32",
    "44.232.150.154/32",
    "44.235.136.122/32",
    "44.237.176.196/32",
    "44.238.116.230/32",
    "44.241.29.51/32",
    "44.241.78.207/32",
    "52.26.247.161/32",
    "52.26.252.137/32",
    "52.34.192.104/32",
    "54.69.4.7/32",
    "54.70.129.13/32",
    "54.149.169.14/32",
    "54.184.188.46/32",
    "54.203.66.5/32",
  "54.212.67.95/32"
  ]
}

variable "allow_all_cidr_blocks" {
  description = "Allow access from all IPs (0.0.0.0/0). WARNING: Only use for testing. Set to false for production."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Confluent Cloud Configuration
# -----------------------------------------------------------------------------
variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key (can be set via CONFLUENT_CLOUD_API_KEY env var)"
  type        = string
  default     = ""
  # Will use environment variable if not provided
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret (can be set via CONFLUENT_CLOUD_API_SECRET env var)"
  type        = string
  sensitive   = true
  default     = ""
  # Will use environment variable if not provided
}

variable "cc_availability" {
  description = "Kafka cluster availability (SINGLE_ZONE or MULTI_ZONE)"
  type        = string
  default     = "SINGLE_ZONE"
}

variable "flink_max_cfu" {
  description = "Maximum CFU for Flink compute pool"
  type        = number
  default     = 20
}

# -----------------------------------------------------------------------------
# ML Inference Configuration
# -----------------------------------------------------------------------------
variable "ml_inference_image" {
  description = "Docker image for ML inference (leave empty to build from source)"
  type        = string
  default     = ""
}

variable "local_architecture" {
  description = "Local machine architecture for Docker builds (amd64 or arm64)"
  type        = string
  default     = "amd64"
}

variable "enable_ml_inference_alb" {
  description = "Enable Application Load Balancer for ML inference service (recommended for production)"
  type        = bool
  default     = false
}

variable "ml_inference_certificate_arn" {
  description = "ACM certificate ARN for HTTPS on ML inference ALB. Leave empty for HTTP-only. Certificate must be in the same region as the ALB."
  type        = string
  default     = ""
}

variable "ml_inference_redirect_http_to_https" {
  description = "Redirect HTTP to HTTPS when certificate is provided"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Sink Configuration
# -----------------------------------------------------------------------------
variable "enable_tableflow" {
  description = "Enable TableFlow for Iceberg table management"
  type        = bool
  default     = true
}

variable "tableflow_provider_integration_id" {
  description = "Confluent provider integration ID for Tableflow BYOB AWS storage. Leave empty to create via Terraform."
  type        = string
  default     = ""
}

variable "confluent_external_id" {
  description = "External ID for Confluent Cloud to assume the IAM role. Get this from Confluent Cloud when setting up provider integration, or use a secure random string."
  type        = string
  sensitive   = true
  default     = ""
}

variable "create_tableflow_topics" {
  description = "Create Kafka topics for Tableflow if they don't exist. Set to false if topics are created by Flink."
  type        = bool
  default     = true
}

variable "enable_redshift" {
  description = "Deploy Redshift Serverless for querying Iceberg tables"
  type        = bool
  default     = false
}
