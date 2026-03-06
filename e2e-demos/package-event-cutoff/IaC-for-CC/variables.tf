# -----------------------------------------------------------------------------
# Confluent / Flink deployment variables
# Set via terraform.tfvars, .auto.tfvars, or environment (TF_VAR_*).
# -----------------------------------------------------------------------------

variable "organization_id" {
  description = "Confluent Cloud organization ID (e.g. org-xxxxx)"
  type        = string
}

variable "environment_id" {
  description = "Confluent Cloud environment ID (e.g. env-xxxxx)"
  type        = string
}

variable "flink_compute_pool_id" {
  description = "Flink compute pool ID (e.g. lfcp-xxxxx)"
  type        = string
}

variable "flink_api_key" {
  description = "Flink API key for the compute pool (Confluent API key with Flink access)"
  type        = string
  sensitive   = true
}

variable "flink_api_secret" {
  description = "Flink API secret for the compute pool"
  type        = string
  sensitive   = true
}

variable "rest_endpoint" {
  description = "Flink region REST endpoint (e.g. https://flink.us-east-1.aws.confluent.cloud)"
  type        = string
}

variable "principal_id" {
  description = "Principal (service account) ID the Flink statements run as (e.g. sa-xxxxx)"
  type        = string
}

variable "sql_current_catalog" {
  description = "Flink SQL current catalog (typically environment display name)"
  type        = string
}

variable "sql_current_database" {
  description = "Flink SQL current database (typically Kafka cluster display name)"
  type        = string
}

variable "prefix" {
  description = "Prefix for Flink statement names"
  type        = string
  default     = "seph"
}
