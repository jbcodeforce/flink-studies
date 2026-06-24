output "flink_developer_service_account_id" {
  description = "Service account ID (principal for Flink statements)"
  value       = confluent_service_account.flink_developer.id
}

output "flink_developer_service_account_display_name" {
  description = "Service account display name"
  value       = confluent_service_account.flink_developer.display_name
}

output "flink_api_key_id" {
  description = "Flink-scoped API key ID (HTTP Basic auth username)"
  value       = confluent_api_key.flink_developer.id
}

output "flink_api_key_secret" {
  description = "Flink-scoped API key secret (HTTP Basic auth password)"
  value       = confluent_api_key.flink_developer.secret
  sensitive   = true
}

output "cloud_provider" {
  description = "Cloud provider for compute pool API (e.g. GCP)"
  value       = var.cloud_provider
}

output "cloud_region" {
  description = "Cloud region for compute pool API (e.g. us-central1)"
  value       = var.cloud_region
}

output "organization_id" {
  description = "Confluent Cloud organization ID"
  value       = local.org_id
}

output "environment_id" {
  description = "Confluent Cloud environment ID"
  value       = local.env_id
}

output "environment_display_name" {
  description = "Environment display name (Flink sql.current-catalog)"
  value       = local.sql_current_catalog
}

output "kafka_cluster_id" {
  description = "Kafka cluster ID (empty when not created by this module)"
  value       = var.create_kafka_cluster ? confluent_kafka_cluster.kafka[0].id : null
}

output "kafka_cluster_display_name" {
  description = "Kafka cluster display name (Flink sql.current-database)"
  value       = local.sql_current_database
}

output "kafka_bootstrap_endpoint" {
  description = "Kafka bootstrap endpoint (empty when cluster not created)"
  value       = var.create_kafka_cluster ? confluent_kafka_cluster.kafka[0].bootstrap_endpoint : null
}

output "flink_compute_pool_id" {
  description = "Flink compute pool ID"
  value       = local.flink_compute_pool_id
}

output "flink_compute_pool_display_name" {
  description = "Flink compute pool display name"
  value       = var.create_flink_compute_pool ? confluent_flink_compute_pool.pool[0].display_name : null
}

output "flink_rest_endpoint" {
  description = "Flink region REST base URL (e.g. https://flink.us-central1.gcp.confluent.cloud)"
  value       = local.flink_rest_endpoint
}

output "flink_statements_url" {
  description = "Flink SQL statements REST API base URL for this org/env"
  value       = "${local.flink_rest_endpoint}/sql/v1/organizations/${local.org_id}/environments/${local.env_id}/statements"
}

output "sql_current_catalog" {
  description = "Default sql.current-catalog for statement properties"
  value       = local.sql_current_catalog
}

output "sql_current_database" {
  description = "Default sql.current-database for statement properties"
  value       = local.sql_current_database
}
