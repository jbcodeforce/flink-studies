# -----------------------------------------------------------------------------
# Variables Configuration
# txp_dim_customers Flink Statements
# -----------------------------------------------------------------------------

variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key (can be set via CONFLUENT_CLOUD_API_KEY env var)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret (can be set via CONFLUENT_CLOUD_API_SECRET env var)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "iac_state_path" {
  description = "Path to the IaC terraform state file (relative to this terraform directory)"
  type        = string
  default     = "../../IaC/terraform.tfstate"
}

variable "cloud_region" {
  description = "AWS region for Flink deployment (must match IaC configuration)"
  type        = string
  default     = "us-east-2"
}

variable "statement_name_prefix" {
  description = "Prefix for Flink statement names"
  type        = string
  default     = "dev-usw2-txp"
}

variable "app_manager_service_account_id" {
  description = "App Manager service account ID (owns Flink API key). Can be set manually or will try to get from IaC remote state."
  type        = string
  default     = ""
}
