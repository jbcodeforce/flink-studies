# -----------------------------------------------------------------------------
# Variables — Layer 0 (Primary Flink)
# -----------------------------------------------------------------------------

variable "prefix" {
  description = "Short prefix used in all resource display names"
  type        = string
  default     = "j9r"
}

variable "primary_environment_id" {
  description = "Confluent Cloud environment ID for the existing primary (j9r-env)"
  type        = string
  default     = "env-yk3jm6"
}

variable "primary_kafka_cluster_id" {
  description = "Kafka cluster ID for the existing primary (j9r-kafka)"
  type        = string
  default     = "lkc-7v233w"
}

variable "primary_schema_registry_id" {
  description = "Schema Registry cluster ID for the existing primary SR"
  type        = string
  default     = "lsrc-3oxyv2"
}

variable "primary_region" {
  description = "AWS / Confluent Cloud region of the primary site"
  type        = string
  default     = "us-west-2"
}

variable "flink_max_cfu" {
  description = "Maximum CFUs for the DR-demo Flink compute pool on primary"
  type        = number
  default     = 10
}

variable "topic_partitions" {
  description = "Partition count for demo topics"
  type        = number
  default     = 6
}
