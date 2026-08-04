variable "environment_id" {
  description = "Confluent Cloud environment ID to import (j9r-env)"
  type        = string
  default     = "env-yk3jm6"
}

variable "kafka_cluster_id" {
  description = "Kafka cluster ID to import (j9r-kafka)"
  type        = string
  default     = "lkc-7v233w"
}

variable "env_manager_sa_id" {
  description = "Service account ID to import for env/demo operations"
  type        = string
  default     = "sa-111z1z"
}

variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key (or set CONFLUENT_CLOUD_API_KEY)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret (or set CONFLUENT_CLOUD_API_SECRET)"
  type        = string
  sensitive   = true
  default     = ""
}
