# -----------------------------------------------------------------------------
# Outputs — Layer 0 (Primary Flink)
# All values consumed by:
#   - export-env.sh primary
#   - Layer 1 (01-dr-site) via terraform_remote_state
#   - Layer 2 (02-cluster-link) via terraform_remote_state
#   - Layer 3 (03-schema-linking) via terraform_remote_state
# -----------------------------------------------------------------------------

# --- Environment ---

output "primary_environment_id" {
  description = "Primary Confluent Cloud environment ID"
  value       = data.confluent_environment.primary.id
}

output "primary_environment_display_name" {
  description = "Primary environment display name (also the Flink catalog name)"
  value       = data.confluent_environment.primary.display_name
}

output "primary_environment_resource_name" {
  description = "Primary environment CRN (used for role binding patterns in later layers)"
  value       = data.confluent_environment.primary.resource_name
}

# --- Kafka cluster ---

output "primary_kafka_cluster_id" {
  description = "Primary Kafka cluster ID"
  value       = data.confluent_kafka_cluster.primary.id
}

output "primary_kafka_cluster_display_name" {
  description = "Primary Kafka cluster display name (also the Flink database name)"
  value       = data.confluent_kafka_cluster.primary.display_name
}

output "primary_bootstrap_endpoint" {
  description = "Primary Kafka bootstrap endpoint"
  value       = data.confluent_kafka_cluster.primary.bootstrap_endpoint
}

output "primary_rest_endpoint" {
  description = "Primary Kafka REST endpoint"
  value       = data.confluent_kafka_cluster.primary.rest_endpoint
}

output "primary_kafka_rbac_crn" {
  description = "Primary Kafka cluster RBAC CRN (used for role bindings in later layers)"
  value       = data.confluent_kafka_cluster.primary.rbac_crn
}

# --- Schema Registry ---

output "primary_schema_registry_id" {
  description = "Primary Schema Registry cluster ID"
  value       = data.confluent_schema_registry_cluster.primary.id
}

output "primary_schema_registry_rest_endpoint" {
  description = "Primary Schema Registry REST endpoint"
  value       = data.confluent_schema_registry_cluster.primary.rest_endpoint
}

output "primary_schema_registry_resource_name" {
  description = "Primary SR CRN (used for subject-scoped role bindings in later layers)"
  value       = data.confluent_schema_registry_cluster.primary.resource_name
}

# --- Flink ---

output "primary_flink_compute_pool_id" {
  description = "DR-demo Flink compute pool ID on primary site"
  value       = confluent_flink_compute_pool.primary.id
}

output "primary_flink_rest_endpoint" {
  description = "Flink REST endpoint for primary region"
  value       = data.confluent_flink_region.primary.rest_endpoint
}

output "primary_region" {
  description = "Primary AWS / Confluent Cloud region"
  value       = var.primary_region
}

output "flink_api_key_primary" {
  description = "Flink API key ID for primary site"
  value       = confluent_api_key.flink_primary.id
  sensitive   = true
}

output "flink_api_secret_primary" {
  description = "Flink API key secret for primary site"
  value       = confluent_api_key.flink_primary.secret
  sensitive   = true
}

# --- Flink SA (needed by Layer 2 for cluster-link role bindings) ---

output "dr_flink_sa_id" {
  description = "DR-demo Flink service account ID"
  value       = confluent_service_account.dr_flink.id
}

# --- Producer ---

output "producer_primary_api_key" {
  description = "Kafka API key ID for DR demo producer on primary"
  value       = confluent_api_key.producer_primary_kafka.id
  sensitive   = true
}

output "producer_primary_api_secret" {
  description = "Kafka API key secret for DR demo producer on primary"
  value       = confluent_api_key.producer_primary_kafka.secret
  sensitive   = true
}

output "producer_sr_primary_api_key" {
  description = "SR API key ID for DR demo producer on primary"
  value       = confluent_api_key.producer_sr_primary.id
  sensitive   = true
}

output "producer_sr_primary_api_secret" {
  description = "SR API key secret for DR demo producer on primary"
  value       = confluent_api_key.producer_sr_primary.secret
  sensitive   = true
}

# --- Producer SA (needed by Layer 2 for cluster-link source credentials) ---

output "dr_producer_sa_id" {
  description = "DR-demo producer service account ID"
  value       = confluent_service_account.dr_producer.id
}
