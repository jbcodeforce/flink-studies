# -----------------------------------------------------------------------------
# Outputs — Layer 1 (DR site)
# Consumed by:
#   - scripts/generate-outputs.sh -> export-env.sh dr
#   - Layer 2 (02-cluster-link) and Layer 3 (03-schema-linking) via terraform_remote_state
# -----------------------------------------------------------------------------

# --- Environment ---

output "dr_environment_id" {
  description = "DR Confluent Cloud environment ID"
  value       = confluent_environment.dr.id
}

output "dr_environment_display_name" {
  description = "DR environment display name (also the Flink catalog name)"
  value       = confluent_environment.dr.display_name
}

output "dr_environment_resource_name" {
  description = "DR environment CRN"
  value       = confluent_environment.dr.resource_name
}

# --- Kafka cluster ---

output "dr_kafka_cluster_id" {
  description = "DR Kafka cluster ID"
  value       = confluent_kafka_cluster.dr.id
}

output "dr_kafka_cluster_display_name" {
  description = "DR Kafka cluster display name (also the Flink database name)"
  value       = confluent_kafka_cluster.dr.display_name
}

output "dr_bootstrap_endpoint" {
  description = "DR Kafka bootstrap endpoint (private; resolvable only inside the VPC)"
  value       = confluent_kafka_cluster.dr.bootstrap_endpoint
}

output "dr_rest_endpoint" {
  description = "DR Kafka REST endpoint (private)"
  value       = confluent_kafka_cluster.dr.rest_endpoint
}

output "dr_kafka_rbac_crn" {
  description = "DR Kafka cluster RBAC CRN"
  value       = confluent_kafka_cluster.dr.rbac_crn
}

# --- Schema Registry ---

output "dr_schema_registry_id" {
  description = "DR Schema Registry cluster ID"
  value       = data.confluent_schema_registry_cluster.dr.id
}

output "dr_schema_registry_rest_endpoint" {
  description = "DR Schema Registry REST endpoint"
  value       = data.confluent_schema_registry_cluster.dr.rest_endpoint
}

output "dr_schema_registry_resource_name" {
  description = "DR SR CRN"
  value       = data.confluent_schema_registry_cluster.dr.resource_name
}

# --- Flink ---

output "dr_flink_compute_pool_id" {
  description = "DR Flink compute pool ID"
  value       = confluent_flink_compute_pool.dr.id
}

output "dr_flink_rest_endpoint" {
  description = "Flink REST endpoint for the DR region (public)"
  value       = data.confluent_flink_region.dr.rest_endpoint
}

output "dr_flink_private_endpoint" {
  description = "Optional private Flink endpoint for the dbt dr profile (empty = use public Flink API)"
  value       = var.flink_private_endpoint
}

output "dr_region" {
  description = "DR AWS / Confluent Cloud region"
  value       = var.dr_region
}

# --- Service account and keys (sensitive) ---

output "dr_manager_sa_id" {
  description = "DR manager service account ID (cluster link destination and schema exporter target)"
  value       = confluent_service_account.dr_manager.id
}

output "flink_api_key_dr" {
  description = "Flink API key ID for the DR site"
  value       = confluent_api_key.flink_dr.id
  sensitive   = true
}

output "flink_api_secret_dr" {
  description = "Flink API key secret for the DR site"
  value       = confluent_api_key.flink_dr.secret
  sensitive   = true
}

output "producer_dr_api_key" {
  description = "Kafka API key ID for the DR cluster"
  value       = confluent_api_key.producer_dr_kafka.id
  sensitive   = true
}

output "producer_dr_api_secret" {
  description = "Kafka API key secret for the DR cluster"
  value       = confluent_api_key.producer_dr_kafka.secret
  sensitive   = true
}

output "producer_sr_dr_api_key" {
  description = "Schema Registry API key ID for the DR site"
  value       = confluent_api_key.producer_sr_dr.id
  sensitive   = true
}

output "producer_sr_dr_api_secret" {
  description = "Schema Registry API key secret for the DR site"
  value       = confluent_api_key.producer_sr_dr.secret
  sensitive   = true
}

# --- Network and bastion ---

output "dr_platt_id" {
  description = "Confluent PrivateLink Attachment ID"
  value       = confluent_private_link_attachment.dr.id
}

output "dr_platt_dns_domain" {
  description = "DNS domain of the PrivateLink Attachment (wildcard-resolved by the private zone)"
  value       = confluent_private_link_attachment.dr.dns_domain
}

output "dr_vpc_id" {
  description = "DR VPC ID"
  value       = aws_vpc.dr.id
}

output "dr_bastion_instance_id" {
  description = "Bastion EC2 instance ID (use with: aws ssm start-session --target <id>)"
  value       = aws_instance.bastion.id
}

output "dr_outputs_parameter_name" {
  description = "Parameter Store name that carries iac-outputs.json to the bastion (see scripts/push-outputs.sh)"
  value       = var.outputs_parameter_name
}

output "dr_bastion_ssm_command" {
  description = "Command that opens a shell on the bastion"
  value       = "aws ssm start-session --target ${aws_instance.bastion.id} --region ${var.dr_region}"
}
