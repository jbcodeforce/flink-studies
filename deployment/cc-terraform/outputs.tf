output "org_id" {
  value = data.confluent_organization.my_org.id
}

output "env_id" {
  value = confluent_environment.env.id
}

# Kafka Cluster Keys

output "kafka_standard_id" {
  value = confluent_kafka_cluster.standard.id
}

output "kafka_standard_bootstrap_endpoint" {
  value = confluent_kafka_cluster.standard.bootstrap_endpoint
}

output "kafka_standard_rest_endpoint" {
  value = confluent_kafka_cluster.standard.rest_endpoint
}

output "kafka_standard_api_key_id" {
  value = confluent_api_key.standard-kafka-api-key.id
}

output "kafka_standard_api_key_secret" {
  value = nonsensitive(confluent_api_key.standard-kafka-api-key.secret)
}

# Schema Registry Keys

output "sr_prod_id" {
  value = data.confluent_schema_registry_cluster.essentials.id
}

output "sr_prod_connection" {
  value = data.confluent_schema_registry_cluster.essentials.rest_endpoint
}

output "sr_prod_api_key_id" {
  value = confluent_api_key.schema-registry-api-key.id
}

output "sr_prod_api_key_secret" {
  value = nonsensitive(confluent_api_key.schema-registry-api-key.secret)
}

# Flink Service Account

output "flink_app_sa_id" {
  value = confluent_service_account.flink-app.id
}

output "flink_developer_sa_id" {
  value = confluent_service_account.flink-developer-sa.id
}

output "flink_developer_sa_flink_api_key_id" {
  value = confluent_api_key.flink-developer-sa-flink-api-key.id
}

output "flink_developer_sa_flink_api_key_secret" {
  value = nonsensitive(confluent_api_key.flink-developer-sa-flink-api-key.secret)
}

# Flink Compute Pool

output "flink_compute_pool_id" {
  value = confluent_flink_compute_pool.default.id
}

output "flink_rest_endpoint" {
  value = data.confluent_flink_region.flink_region.rest_endpoint
}