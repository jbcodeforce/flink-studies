# -----------------------------------------------------------------------------
# Outputs
# Card Transaction Processing Demo
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# AWS Outputs
# -----------------------------------------------------------------------------
output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.card_tx_db.endpoint
}

output "rds_address" {
  description = "RDS PostgreSQL address (hostname only)"
  value       = aws_db_instance.card_tx_db.address
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.card_tx_db.db_name
}

output "rds_subnet_group_name" {
  description = "RDS DB subnet group name"
  value       = aws_db_subnet_group.card_tx_db_subnet_group.name
}

output "rds_subnet_group_subnets" {
  description = "List of subnet IDs in the RDS subnet group (potential subnets RDS can use)"
  value       = aws_db_subnet_group.card_tx_db_subnet_group.subnet_ids
}

output "rds_subnet_group_subnet_details" {
  description = "Detailed information about subnets in the RDS subnet group"
  value = {
    for subnet_id in aws_db_subnet_group.card_tx_db_subnet_group.subnet_ids : subnet_id => {
      subnet_id    = subnet_id
      cidr_block   = data.aws_subnet.all[subnet_id].cidr_block
      availability_zone = data.aws_subnet.all[subnet_id].availability_zone
      route_table_id = try(
        data.aws_route_tables.subnet_route_tables[subnet_id].ids[0],
        "NO_ROUTE_TABLE"
      )
      has_igw_route = try(
        local.subnet_igw_validation[subnet_id].has_igw_route,
        false
      )
    }
  }
}

output "rds_availability_zone" {
  description = "Availability zone where RDS instance is deployed"
  value       = aws_db_instance.card_tx_db.availability_zone
}

output "rds_instance_id" {
  description = "RDS instance identifier (use this to query AWS for actual subnet)"
  value       = aws_db_instance.card_tx_db.id
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.card_tx_db_sg.id
}

output "rds_allowed_cidr_blocks" {
  description = "All CIDR blocks allowed to access RDS (Confluent Cloud + user IPs)"
  value       = local.all_allowed_cidr_blocks
}

output "confluent_cloud_cidr_blocks" {
  description = "Confluent Cloud CIDR blocks configured for CDC connector access"
  value       = var.confluent_cloud_cidr_blocks
}

output "s3_bucket_name" {
  description = "S3 bucket for Iceberg sink"
  value       = aws_s3_bucket.card_tx_iceberg.bucket
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.card_tx_iceberg.arn
}

output "ecr_repository_url" {
  description = "ECR repository URL for ML inference container"
  value       = aws_ecr_repository.card_tx_ml_inference_repo.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.card_tx_ecs_cluster.name
}

# -----------------------------------------------------------------------------
# Confluent Cloud Outputs
# -----------------------------------------------------------------------------
output "confluent_environment_id" {
  description = "Confluent Cloud environment ID"
  value       = confluent_environment.card_tx_env.id
}

output "kafka_cluster_id" {
  description = "Kafka cluster ID"
  value       = confluent_kafka_cluster.card_tx_cluster.id
}

output "kafka_bootstrap_endpoint" {
  description = "Kafka bootstrap endpoint"
  value       = confluent_kafka_cluster.card_tx_cluster.bootstrap_endpoint
}

output "kafka_rest_endpoint" {
  description = "Kafka REST endpoint"
  value       = confluent_kafka_cluster.card_tx_cluster.rest_endpoint
}

output "schema_registry_endpoint" {
  description = "Schema Registry REST endpoint"
  value       = data.confluent_schema_registry_cluster.card_tx_sr.rest_endpoint
}

output "flink_compute_pool_id" {
  description = "Flink compute pool ID"
  value       = confluent_flink_compute_pool.card_tx_flink_pool.id
}

# -----------------------------------------------------------------------------
# API Keys (Sensitive)
# -----------------------------------------------------------------------------
output "kafka_api_key" {
  description = "Kafka API Key ID"
  value       = confluent_api_key.app_manager_kafka_key.id
  sensitive   = false
}

output "kafka_api_secret" {
  description = "Kafka API Secret"
  value       = confluent_api_key.app_manager_kafka_key.secret
  sensitive   = true
}

output "schema_registry_api_key" {
  description = "Schema Registry API Key ID"
  value       = confluent_api_key.app_manager_sr_key.id
  sensitive   = false
}

output "schema_registry_api_secret" {
  description = "Schema Registry API Secret"
  value       = confluent_api_key.app_manager_sr_key.secret
  sensitive   = true
}

output "flink_api_key" {
  description = "Flink API Key ID"
  value       = confluent_api_key.app_manager_flink_key.id
  sensitive   = false
}

output "flink_api_secret" {
  description = "Flink API Secret"
  value       = confluent_api_key.app_manager_flink_key.secret
  sensitive   = true
}

output "tableflow_api_key" {
  description = "Tableflow API Key ID"
  value       = var.enable_tableflow ? confluent_api_key.app_manager_tableflow_key[0].id : null
  sensitive   = false
}

output "tableflow_api_secret" {
  description = "Tableflow API Secret"
  value       = var.enable_tableflow ? confluent_api_key.app_manager_tableflow_key[0].secret : null
  sensitive   = true
}

# -----------------------------------------------------------------------------
# CDC Topics
# -----------------------------------------------------------------------------
output "cdc_customers_topic" {
  description = "CDC topic for customers table"
  value       = "${var.prefix}.public.customers"
}

output "cdc_transactions_topic" {
  description = "CDC topic for transactions table"
  value       = "${var.prefix}.public.transactions"
}

output "cdc_connector_name" {
  description = "CDC connector name"
  value       = "${var.prefix}-cdc-source"
}

output "cdc_connector_id" {
  description = "CDC connector ID"
  value       = confluent_connector.card_tx_cdc_source.id
}

# -----------------------------------------------------------------------------
# Tableflow Outputs (Conditional)
# -----------------------------------------------------------------------------
output "tableflow_topic_name" {
  description = "Tableflow-enabled topic name (tx_aggregations)"
  value       = var.enable_tableflow ? confluent_tableflow_topic.card_tx_aggregations[0].display_name : null
}

output "tableflow_topic_id" {
  description = "Tableflow topic ID"
  value       = var.enable_tableflow ? confluent_tableflow_topic.card_tx_aggregations[0].id : null
}

# -----------------------------------------------------------------------------
# Connection Strings
# -----------------------------------------------------------------------------
output "psql_connection_string" {
  description = "PostgreSQL connection string (password excluded)"
  value       = "postgresql://${var.db_username}@${aws_db_instance.card_tx_db.address}:${aws_db_instance.card_tx_db.port}/${aws_db_instance.card_tx_db.db_name}"
}

# -----------------------------------------------------------------------------
# Redshift Outputs (Conditional)
# -----------------------------------------------------------------------------
output "redshift_endpoint" {
  description = "Redshift Serverless endpoint"
  value       = var.enable_redshift ? aws_redshiftserverless_workgroup.card_tx_workgroup[0].endpoint[0].address : null
}

output "redshift_database" {
  description = "Redshift database name"
  value       = var.enable_redshift ? aws_redshiftserverless_namespace.card_tx_namespace[0].db_name : null
}
