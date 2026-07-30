# -----------------------------------------------------------------------------
# Variables — DR Car Rides Demo
# -----------------------------------------------------------------------------

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "dr-rides"
}

variable "owner_email" {
  description = "Owner email for tagging"
  type        = string
}

variable "primary_region" {
  description = "AWS / Confluent Cloud region for the primary Kafka cluster and Flink pool"
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "AWS / Confluent Cloud region for the DR Kafka cluster and Flink pool"
  type        = string
  default     = "us-west-2"
}

variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API key (or set CONFLUENT_CLOUD_API_KEY)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API secret (or set CONFLUENT_CLOUD_API_SECRET)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cc_availability" {
  description = "Kafka cluster availability (SINGLE_ZONE or MULTI_ZONE)"
  type        = string
  default     = "SINGLE_ZONE"
}

variable "flink_max_cfu" {
  description = "Max CFU per Flink compute pool"
  type        = number
  default     = 10
}

variable "topic_partitions" {
  description = "Partitions for demo topics"
  type        = number
  default     = 6
}

variable "enable_tableflow" {
  description = "Provision Tableflow BYOB AWS integration, S3, and Glue"
  type        = bool
  default     = true
}

variable "confluent_external_id" {
  description = "External ID for Confluent to assume the Tableflow IAM role (from provider integration UI if updating trust)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cluster_link_name" {
  description = "Bidirectional cluster link name (same name both directions)"
  type        = string
  default     = "dr-rides-bidirectional"
}
