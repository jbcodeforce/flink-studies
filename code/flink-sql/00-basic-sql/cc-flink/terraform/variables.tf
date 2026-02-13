variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API key (provider auth). Can use CONFLUENT_CLOUD_API_KEY env instead."
  type        = string
  default     = ""
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API secret (provider auth). Can use CONFLUENT_CLOUD_API_SECRET env instead."
  type        = string
  default     = ""
  sensitive   = true
}

variable "environment_id" {
  description = "Existing Confluent Cloud environment ID"
  type        = string
}

variable "kafka_cluster_id" {
  description = "Existing Kafka cluster ID"
  type        = string
}

variable "flink_compute_pool_id" {
  description = "Existing Flink compute pool ID"
  type        = string
}

variable "principal_id" {
  description = "Service account ID (principal for Flink statements)"
  type        = string
}

variable "flink_api_key" {
  description = "API key ID for Flink (scoped to Flink region, owned by principal)"
  type        = string
  sensitive   = true
}

variable "flink_api_secret" {
  description = "API key secret for Flink"
  type        = string
  sensitive   = true
}

variable "flink_rest_endpoint" {
  description = "Flink REST endpoint URL"
  type        = string
  default = ' https://flink.us-west-2.aws.confluent.cloud'
}

variable "statement_name_prefix" {
  description = "Prefix for Flink statement names"
  type        = string
  default     = "basic-sql"
}
