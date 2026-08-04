# Focused outputs for DR car-rides IaC (terraform_remote_state).
# Primary = j9r-env / j9r-kafka only; other imported resources are catalog-only.

output "environment_id" {
  value = confluent_environment.j9r_env_28.id
}

output "environment_display_name" {
  value = confluent_environment.j9r_env_28.display_name
}

output "environment_resource_name" {
  value = confluent_environment.j9r_env_28.resource_name
}

output "kafka_cluster_id" {
  value = confluent_kafka_cluster.j9r_kafka_10.id
}

output "kafka_display_name" {
  value = confluent_kafka_cluster.j9r_kafka_10.display_name
}

output "kafka_bootstrap_endpoint" {
  value = confluent_kafka_cluster.j9r_kafka_10.bootstrap_endpoint
}

output "kafka_rest_endpoint" {
  value = confluent_kafka_cluster.j9r_kafka_10.rest_endpoint
}

output "kafka_rbac_crn" {
  value = confluent_kafka_cluster.j9r_kafka_10.rbac_crn
}

output "kafka_region" {
  value = confluent_kafka_cluster.j9r_kafka_10.region
}

output "env_manager_sa_id" {
  value = confluent_service_account.j9r_env_manager_110.id
}

output "kafka_mgr_sa_id" {
  value = confluent_service_account.j9r_kafka_mgr_3.id
}

output "flink_app_sa_id" {
  value = confluent_service_account.j9r_flink_app_94.id
}

output "fd_sa_id" {
  value = confluent_service_account.j9r_fd_sa_19.id
}
