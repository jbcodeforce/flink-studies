# -----------------------------------------------------------------------------
# Outputs — DR Car Rides Demo (dual env + Schema Linking)
# -----------------------------------------------------------------------------

output "primary_environment_id" {
  value = data.confluent_environment.primary.id
}

output "primary_environment_display_name" {
  value = data.confluent_environment.primary.display_name
}

output "dr_environment_id" {
  value = confluent_environment.dr.id
}

output "dr_environment_display_name" {
  value = confluent_environment.dr.display_name
}

# Alias used by older script snippets — primary env
output "confluent_environment_id" {
  value = data.confluent_environment.primary.id
}

output "primary_schema_registry_id" {
  value = data.confluent_schema_registry_cluster.primary.id
}

output "primary_schema_registry_rest_endpoint" {
  value = data.confluent_schema_registry_cluster.primary.rest_endpoint
}

output "dr_schema_registry_id" {
  value = data.confluent_schema_registry_cluster.dr.id
}

output "dr_schema_registry_rest_endpoint" {
  value = data.confluent_schema_registry_cluster.dr.rest_endpoint
}

output "schema_exporter_name" {
  value = confluent_schema_exporter.primary_to_dr.name
}

output "dr_schema_registry_mode" {
  value = confluent_schema_registry_cluster_mode.dr_import.mode
}

output "primary_kafka_cluster_id" {
  value = data.confluent_kafka_cluster.primary.id
}

output "primary_kafka_cluster_display_name" {
  value = data.confluent_kafka_cluster.primary.display_name
}

output "primary_bootstrap_endpoint" {
  value = data.confluent_kafka_cluster.primary.bootstrap_endpoint
}

output "primary_rest_endpoint" {
  value = data.confluent_kafka_cluster.primary.rest_endpoint
}

output "dr_kafka_cluster_id" {
  value = confluent_kafka_cluster.dr.id
}

output "dr_kafka_cluster_display_name" {
  value = confluent_kafka_cluster.dr.display_name
}

output "dr_bootstrap_endpoint" {
  value = confluent_kafka_cluster.dr.bootstrap_endpoint
}

output "dr_rest_endpoint" {
  value = confluent_kafka_cluster.dr.rest_endpoint
}

output "primary_flink_compute_pool_id" {
  value = confluent_flink_compute_pool.primary.id
}

output "dr_flink_compute_pool_id" {
  value = confluent_flink_compute_pool.dr.id
}

output "primary_flink_rest_endpoint" {
  value = data.confluent_flink_region.primary.rest_endpoint
}

output "dr_flink_rest_endpoint" {
  value = data.confluent_flink_region.dr.rest_endpoint
}

output "cluster_link_name" {
  value = var.cluster_link_name
}

output "app_manager_service_account_id" {
  value = data.confluent_service_account.app_manager.id
}

output "flink_service_account_id" {
  value = data.confluent_service_account.flink.id
}

output "flink_api_key_primary" {
  value     = confluent_api_key.flink_primary.id
  sensitive = true
}

output "flink_api_secret_primary" {
  value     = confluent_api_key.flink_primary.secret
  sensitive = true
}

output "flink_api_key_dr" {
  value     = confluent_api_key.flink_dr.id
  sensitive = true
}

output "flink_api_secret_dr" {
  value     = confluent_api_key.flink_dr.secret
  sensitive = true
}

output "producer_primary_api_key" {
  value     = confluent_api_key.producer_primary_kafka.id
  sensitive = true
}

output "producer_primary_api_secret" {
  value     = confluent_api_key.producer_primary_kafka.secret
  sensitive = true
}

output "producer_dr_api_key" {
  value     = confluent_api_key.producer_dr_kafka.id
  sensitive = true
}

output "producer_dr_api_secret" {
  value     = confluent_api_key.producer_dr_kafka.secret
  sensitive = true
}

output "producer_sr_api_key" {
  description = "Primary SR key (steady-state producer)"
  value       = confluent_api_key.producer_sr_primary.id
  sensitive   = true
}

output "producer_sr_api_secret" {
  value     = confluent_api_key.producer_sr_primary.secret
  sensitive = true
}

output "producer_sr_primary_api_key" {
  value     = confluent_api_key.producer_sr_primary.id
  sensitive = true
}

output "producer_sr_primary_api_secret" {
  value     = confluent_api_key.producer_sr_primary.secret
  sensitive = true
}

output "producer_sr_dr_api_key" {
  value     = confluent_api_key.producer_sr_dr.id
  sensitive = true
}

output "producer_sr_dr_api_secret" {
  value     = confluent_api_key.producer_sr_dr.secret
  sensitive = true
}

output "app_manager_primary_kafka_api_key" {
  value     = confluent_api_key.app_manager_primary_kafka.id
  sensitive = true
}

output "app_manager_primary_kafka_api_secret" {
  value     = confluent_api_key.app_manager_primary_kafka.secret
  sensitive = true
}

output "app_manager_dr_kafka_api_key" {
  value     = confluent_api_key.app_manager_dr_kafka.id
  sensitive = true
}

output "app_manager_dr_kafka_api_secret" {
  value     = confluent_api_key.app_manager_dr_kafka.secret
  sensitive = true
}

output "tableflow_provider_integration_id" {
  description = "Primary Tableflow PI (steady state)"
  value       = var.enable_tableflow ? confluent_provider_integration.tableflow_primary[0].id : ""
}

output "tableflow_provider_integration_id_primary" {
  value = var.enable_tableflow ? confluent_provider_integration.tableflow_primary[0].id : ""
}

output "tableflow_provider_integration_id_dr" {
  value = var.enable_tableflow ? confluent_provider_integration.tableflow_dr[0].id : ""
}

output "tableflow_api_key" {
  value     = var.enable_tableflow ? confluent_api_key.tableflow[0].id : ""
  sensitive = true
}

output "tableflow_api_secret" {
  value     = var.enable_tableflow ? confluent_api_key.tableflow[0].secret : ""
  sensitive = true
}

output "primary_s3_bucket_name" {
  value = var.enable_tableflow ? aws_s3_bucket.iceberg_primary[0].bucket : ""
}

output "dr_s3_bucket_name" {
  value = var.enable_tableflow ? aws_s3_bucket.iceberg_dr[0].bucket : ""
}

output "glue_database_primary" {
  value = var.enable_tableflow ? aws_glue_catalog_database.primary[0].name : ""
}

output "glue_database_dr" {
  value = var.enable_tableflow ? aws_glue_catalog_database.dr[0].name : ""
}

output "primary_region" {
  value = var.primary_region
}

output "dr_region" {
  value = var.dr_region
}

output "tableflow_role_arn" {
  value = local.tableflow_role_arn
}

output "schema_linking_note" {
  value = "DR SR mode=IMPORT; exporter ${confluent_schema_exporter.primary_to_dr.name} replicates subjects :*: from primary → DR (schema IDs preserved)"
}
