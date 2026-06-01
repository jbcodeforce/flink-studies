output "prometheus_metrics_api_key_id" {
  description = "Cloud API key ID for Prometheus basic_auth username"
  value       = confluent_api_key.metrics.id
}

output "prometheus_metrics_api_key_secret" {
  description = "Cloud API key secret for Prometheus basic_auth password"
  value       = confluent_api_key.metrics.secret
  sensitive   = true
}

output "kafka_cluster_id" {
  description = "Kafka cluster ID for Prometheus scrape params"
  value       = local.kafka_cluster_id
}

output "schema_registry_id" {
  description = "Schema Registry cluster ID for Prometheus scrape params"
  value       = local.schema_registry_id
}

output "flink_compute_pool_ids" {
  description = "Flink compute pool IDs for Prometheus scrape params"
  value       = local.compute_pool_ids
}

output "prometheus_export_url" {
  description = "Confluent Cloud Metrics API export endpoint"
  value       = "https://api.telemetry.confluent.cloud/v2/metrics/cloud/export"
}
