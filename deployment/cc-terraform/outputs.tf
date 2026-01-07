# Outputs for j9r-env base infrastructure
# These values can be used by dependent Terraform configurations

# ------------------------------------------------------
# Organization
# ------------------------------------------------------

output "org_id" {
  description = "Confluent Cloud organization ID"
  value       = data.confluent_organization.my_org.id
}

# ------------------------------------------------------
# Environment
# ------------------------------------------------------

output "env_id" {
  description = "Confluent Cloud environment ID"
  value       = confluent_environment.env.id
}

output "env_display_name" {
  description = "Environment display name (used as Flink catalog)"
  value       = confluent_environment.env.display_name
}

# ------------------------------------------------------
# Kafka Cluster
# ------------------------------------------------------

output "kafka_cluster_id" {
  description = "Kafka cluster ID"
  value       = confluent_kafka_cluster.standard.id
}

output "kafka_cluster_display_name" {
  description = "Kafka cluster display name (used as Flink database)"
  value       = confluent_kafka_cluster.standard.display_name
}

output "kafka_bootstrap_endpoint" {
  description = "Kafka cluster bootstrap endpoint"
  value       = confluent_kafka_cluster.standard.bootstrap_endpoint
}

output "kafka_rest_endpoint" {
  description = "Kafka cluster REST endpoint"
  value       = confluent_kafka_cluster.standard.rest_endpoint
}

output "kafka_api_key_id" {
  description = "Kafka API key ID (owned by env-manager)"
  value       = confluent_api_key.standard-kafka-api-key.id
}

output "kafka_api_key_secret" {
  description = "Kafka API key secret"
  value       = confluent_api_key.standard-kafka-api-key.secret
  sensitive   = true
}

# ------------------------------------------------------
# Schema Registry
# ------------------------------------------------------

output "schema_registry_id" {
  description = "Schema Registry cluster ID"
  value       = data.confluent_schema_registry_cluster.essentials.id
}

output "schema_registry_rest_endpoint" {
  description = "Schema Registry REST endpoint"
  value       = data.confluent_schema_registry_cluster.essentials.rest_endpoint
}

output "schema_registry_api_key_id" {
  description = "Schema Registry API key ID"
  value       = confluent_api_key.schema-registry-api-key.id
}

output "schema_registry_api_key_secret" {
  description = "Schema Registry API key secret"
  value       = confluent_api_key.schema-registry-api-key.secret
  sensitive   = true
}

# ------------------------------------------------------
# Flink Service Accounts
# ------------------------------------------------------

output "flink_app_sa_id" {
  description = "Flink app service account ID (runtime principal)"
  value       = confluent_service_account.flink-app.id
}

output "flink_developer_sa_id" {
  description = "Flink developer service account ID (deploys statements)"
  value       = confluent_service_account.flink-developer-sa.id
}

output "flink_api_key_id" {
  description = "Flink API key ID (owned by flink-developer-sa)"
  value       = confluent_api_key.flink-developer-sa-flink-api-key.id
}

output "flink_api_key_secret" {
  description = "Flink API key secret"
  value       = confluent_api_key.flink-developer-sa-flink-api-key.secret
  sensitive   = true
}

# ------------------------------------------------------
# Flink Compute Pools
# ------------------------------------------------------

output "flink_dev-j9r-pool_id" {
  description = "dev-j9r-pool Flink compute pool ID"
  value       = confluent_flink_compute_pool.dev-j9r-pool.id
}

output "flink_data_gen_pool_id" {
  description = "Data generation Flink compute pool ID"
  value       = confluent_flink_compute_pool.data-generation.id
}

output "flink_rest_endpoint" {
  description = "Flink region REST endpoint"
  value       = data.confluent_flink_region.flink_region.rest_endpoint
}
