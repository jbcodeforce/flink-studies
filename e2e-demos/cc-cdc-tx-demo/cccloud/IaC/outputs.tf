# -----------------------------------------------------------------------------
# Outputs
# Card Transaction Processing Demo
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# AWS Outputs
# -----------------------------------------------------------------------------
output "cloud_region" {
  description = "AWS region where resources are deployed"
  value       = var.cloud_region
}

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

output "confluent_tableflow_role_arn" {
  description = "IAM role ARN for Confluent Cloud Tableflow provider integration (uses existing role if provided, otherwise created role)"
  value       = local.tableflow_role_arn
}

output "tableflow_provider_integration_id" {
  description = "Confluent provider integration ID for Tableflow"
  value       = var.enable_tableflow && var.tableflow_provider_integration_id == "" ? confluent_provider_integration.tableflow_aws[0].id : var.tableflow_provider_integration_id
}

output "tableflow_provider_integration_external_id" {
  description = "External ID from Confluent provider integration. Use this to update the IAM role trust policy with: terraform output -raw tableflow_provider_integration_external_id"
  value       = var.enable_tableflow && var.tableflow_provider_integration_id == "" ? try(confluent_provider_integration.tableflow_aws[0].aws[0].external_id, null) : null
  sensitive   = false
}

output "ecr_repository_url" {
  description = "ECR repository URL for ML inference container"
  value       = aws_ecr_repository.card_tx_ml_inference_repo.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.card_tx_ecs_cluster.name
}

output "ml_inference_service_name" {
  description = "ECS service name for ML inference"
  value       = aws_ecs_service.card_tx_ml_inference_service.name
}

output "ml_inference_service_arn" {
  description = "ECS service ARN for ML inference"
  value       = aws_ecs_service.card_tx_ml_inference_service.id
}

output "ml_inference_task_definition_arn" {
  description = "ECS task definition ARN for ML inference"
  value       = aws_ecs_task_definition.card_tx_ml_inference_task.arn
}

output "ml_inference_log_group" {
  description = "CloudWatch log group name for ML inference"
  value       = aws_cloudwatch_log_group.card_tx_ml_inference_logs.name
}

output "ml_inference_service_url" {
  description = "URL to access the ML inference service (ALB DNS name if ALB is enabled, otherwise use ECS task IP)"
  value = var.enable_ml_inference_alb ? (
    var.ml_inference_certificate_arn != "" ? "https://${aws_lb.card_tx_ml_inference_alb[0].dns_name}" : "http://${aws_lb.card_tx_ml_inference_alb[0].dns_name}"
  ) : null
}

output "ml_inference_direct_access_info" {
  description = "Information about direct ECS access (when ALB is disabled)"
  value = var.enable_ml_inference_alb ? null : <<-EOT
    To get the direct ECS access URL, use the helper script:
    
      cd IaC
      ./get-ecs-task-url.sh
    
    Or manually get the task IP:
    
      CLUSTER=$(terraform output -raw ecs_cluster_name)
      SERVICE=$(terraform output -raw ml_inference_service_name)
      REGION=$(terraform output -raw cloud_region)
      
      TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE --region $REGION --query 'taskArns[0]' --output text)
      ENI_ID=$(aws ecs describe-tasks --cluster $CLUSTER --tasks $TASK_ARN --region $REGION --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
      PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --region $REGION --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
      
      echo "http://$PUBLIC_IP:8080"
    
    Note: The task IP changes when tasks are restarted. Use the ALB for a stable URL.
  EOT
}

output "ml_inference_alb_dns" {
  description = "Application Load Balancer DNS name for ML inference (if enabled)"
  value       = try(aws_lb.card_tx_ml_inference_alb[0].dns_name, null)
}

output "ml_inference_alb_arn" {
  description = "Application Load Balancer ARN for ML inference (if enabled)"
  value       = try(aws_lb.card_tx_ml_inference_alb[0].arn, null)
}

output "ml_inference_https_url" {
  description = "HTTPS URL for ML inference service (if certificate is configured)"
  value       = var.enable_ml_inference_alb && var.ml_inference_certificate_arn != "" ? "https://${aws_lb.card_tx_ml_inference_alb[0].dns_name}" : null
}

output "ml_inference_certificate_configured" {
  description = "Whether HTTPS certificate is configured for ML inference ALB"
  value       = var.enable_ml_inference_alb && var.ml_inference_certificate_arn != ""
}

# -----------------------------------------------------------------------------
# Glue and Athena Outputs
# -----------------------------------------------------------------------------
output "glue_database_name" {
  description = "Glue database name for Iceberg tables"
  value       = aws_glue_catalog_database.card_tx_iceberg_db.name
}

output "glue_database_arn" {
  description = "Glue database ARN"
  value       = aws_glue_catalog_database.card_tx_iceberg_db.arn
}

output "athena_workgroup_name" {
  description = "Athena workgroup name for querying Iceberg tables"
  value       = aws_athena_workgroup.card_tx_workgroup.name
}

output "athena_workgroup_arn" {
  description = "Athena workgroup ARN"
  value       = aws_athena_workgroup.card_tx_workgroup.arn
}

output "athena_query_results_location" {
  description = "S3 location for Athena query results"
  value       = "s3://${aws_s3_bucket.card_tx_iceberg.bucket}/athena-results/"
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

output "app_manager_service_account_id" {
  description = "App Manager service account ID (owns Flink API key)"
  value       = confluent_service_account.app_manager.id
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
# Connection Strings
# -----------------------------------------------------------------------------
output "psql_connection_string" {
  description = "PostgreSQL connection string (password excluded)"
  value       = "postgresql://${var.db_username}@${aws_db_instance.card_tx_db.address}:${aws_db_instance.card_tx_db.port}/${aws_db_instance.card_tx_db.db_name}"
}

