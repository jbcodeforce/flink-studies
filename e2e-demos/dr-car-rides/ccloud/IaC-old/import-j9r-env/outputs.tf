# Outputs for DR car-rides IaC (terraform_remote_state).

output "environment_id" {
  value = confluent_environment.env.id
}

output "environment_display_name" {
  value = confluent_environment.env.display_name
}

output "environment_resource_name" {
  value = confluent_environment.env.resource_name
}

output "kafka_cluster_id" {
  value = confluent_kafka_cluster.standard.id
}

output "kafka_display_name" {
  value = confluent_kafka_cluster.standard.display_name
}

output "kafka_bootstrap_endpoint" {
  value = confluent_kafka_cluster.standard.bootstrap_endpoint
}

output "kafka_rest_endpoint" {
  value = confluent_kafka_cluster.standard.rest_endpoint
}

output "kafka_rbac_crn" {
  value = confluent_kafka_cluster.standard.rbac_crn
}

output "kafka_region" {
  value = confluent_kafka_cluster.standard.region
}

output "env_manager_sa_id" {
  value = confluent_service_account.env-manager.id
}
