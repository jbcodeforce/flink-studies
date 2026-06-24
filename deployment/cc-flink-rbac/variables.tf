variable "prefix" {
  description = "Prefix for resource display names"
  type        = string
  default     = "j9r-rbac"
}

variable "cloud_provider" {
  description = "Cloud provider (GCP, AWS, or AZURE)"
  type        = string
  default     = "GCP"
}

variable "cloud_region" {
  description = "Cloud region (e.g. us-central1 on GCP)"
  type        = string
  default     = "us-central1"
}

# --- Infrastructure creation -------------------------------------------------

variable "create_environment" {
  description = "Create a Confluent Cloud environment"
  type        = bool
  default     = true
}

variable "create_kafka_cluster" {
  description = "Create a Kafka cluster in the target environment"
  type        = bool
  default     = true
}

variable "create_flink_compute_pool" {
  description = "Create a Flink compute pool in the target environment"
  type        = bool
  default     = true
}

variable "environment_display_name" {
  description = "Environment display name (Flink sql.current-catalog). Required naming context when create_environment is false; also used as display name when create_environment is true (defaults to {prefix}-env)."
  type        = string
  default     = ""
}

variable "kafka_cluster_display_name" {
  description = "Kafka cluster display name (Flink sql.current-database)"
  type        = string
  default     = ""
}

variable "kafka_cluster_tier" {
  description = "Kafka cluster tier: basic or standard (DeveloperRead/Write topic bindings require standard)"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["basic", "standard"], var.kafka_cluster_tier)
    error_message = "kafka_cluster_tier must be basic or standard."
  }

  validation {
    condition     = !var.create_kafka_cluster || var.kafka_cluster_tier == "standard"
    error_message = "kafka_cluster_tier must be standard when create_kafka_cluster is true (Basic clusters do not support topic-level DeveloperRead/DeveloperWrite)."
  }
}

variable "kafka_topic_pattern" {
  description = "Kafka topic name or wildcard for DeveloperRead/DeveloperWrite/DeveloperManage CRN suffix (e.g. * for all topics)"
  type        = string
  default     = "*"
}

variable "schema_registry_subject_pattern" {
  description = "Schema Registry subject pattern for DeveloperRead/DeveloperWrite (e.g. * or gcp_demo*)"
  type        = string
  default     = "*"
}

variable "flink_transactional_id_prefix" {
  description = "Transactional-id prefix for Flink exactly-once bindings (Confluent default: _confluent-flink_)"
  type        = string
  default     = "_confluent-flink_"
}

variable "kafka_availability" {
  description = "Kafka cluster availability (SINGLE_ZONE or MULTI_ZONE)"
  type        = string
  default     = "SINGLE_ZONE"
}

variable "flink_compute_pool_display_name" {
  description = "Flink compute pool display name"
  type        = string
  default     = ""
}

variable "flink_max_cfu" {
  description = "Maximum CFU for the Flink compute pool"
  type        = number
  default     = 10
}



# --- Existing resources (when not creating) ------------------------------------

variable "use_remote_state" {
  description = "Read environment and compute pool IDs from cc-terraform local state"
  type        = bool
  default     = false
}

variable "cc_terraform_state_path" {
  description = "Path to cc-terraform terraform.tfstate"
  type        = string
  default     = "../cc-terraform/terraform.tfstate"
}

variable "organization_id" {
  description = "Override organization ID (defaults to data source)"
  type        = string
  default     = ""
}

variable "environment_id" {
  description = "Existing environment ID (required when create_environment is false)"
  type        = string
  default     = ""

  validation {
    condition     = var.create_environment || var.use_remote_state || var.environment_id != ""
    error_message = "environment_id is required when create_environment and use_remote_state are both false."
  }
}

variable "flink_principal_id" {
  type        = string
}

variable "flink_rest_endpoint" {
  type        = string
}

variable "flink_api_key" {
  type        = string
  sensitive   = true
}


variable "flink_api_secret" {
  type        = string
  sensitive   = true
}


variable "flink_compute_pool_id" {
  description = "Existing Flink compute pool ID (when create_flink_compute_pool is false)"
  type        = string
  default     = ""
}

variable "sql_current_catalog" {
  description = "Override Flink sql.current-catalog (defaults to environment display name)"
  type        = string
  default     = ""
}

variable "sql_current_database" {
  description = "Override Flink sql.current-database (defaults to Kafka cluster display name)"
  type        = string
  default     = ""
}

# Optional Schema Registry provider config (all four required together if any are set).
# Defaults are empty strings so partial SCHEMA_REGISTRY_* shell env vars do not break plan.

variable "schema_registry_id" {
  description = "Schema Registry cluster ID (or SCHEMA_REGISTRY_ID env var when non-empty)"
  type        = string
  default     = ""

  validation {
    condition = (
      (var.schema_registry_id == "" && var.schema_registry_rest_endpoint == "" && var.schema_registry_api_key == "" && var.schema_registry_api_secret == "") ||
      (var.schema_registry_id != "" && var.schema_registry_rest_endpoint != "" && var.schema_registry_api_key != "" && var.schema_registry_api_secret != "")
    )
    error_message = "Set all four schema_registry_* variables together, or leave all empty."
  }
}

variable "schema_registry_rest_endpoint" {
  description = "Schema Registry REST endpoint (or SCHEMA_REGISTRY_REST_ENDPOINT env var)"
  type        = string
  default     = ""
}

variable "schema_registry_api_key" {
  description = "Schema Registry API key (or SCHEMA_REGISTRY_API_KEY env var)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "schema_registry_api_secret" {
  description = "Schema Registry API secret (or SCHEMA_REGISTRY_API_SECRET env var)"
  type        = string
  sensitive   = true
  default     = ""
}

