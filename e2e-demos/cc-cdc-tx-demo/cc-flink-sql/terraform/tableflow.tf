# -----------------------------------------------------------------------------
# Tableflow Configuration
# Enable Tableflow on topics after DDL statements create tables with schemas
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Local Values for Tableflow
# -----------------------------------------------------------------------------
locals {
  # Topic names that need Tableflow enabled
  # These match the table names created by DDL statements
  tableflow_topics = {
    "txp_fct_hourly_tx_metrics" = "txp_fct_hourly_tx_metrics"
    "txp_dim_enriched_tx"       = "txp_dim_enriched_tx"
  }
  
  # Get Tableflow configuration from IaC remote state
  # Tableflow is enabled if provider integration ID exists and is not empty
  tableflow_provider_integration_id = try(data.terraform_remote_state.iac.outputs.tableflow_provider_integration_id, "")
  enable_tableflow = local.tableflow_provider_integration_id != null && local.tableflow_provider_integration_id != ""
  s3_bucket_name = try(data.terraform_remote_state.iac.outputs.s3_bucket_name, "")
}

# -----------------------------------------------------------------------------
# Tableflow Enablement
# -----------------------------------------------------------------------------
# Enable Tableflow on topics AFTER DDL statements have created the tables
# This ensures topics have schemas before Tableflow is enabled

# Enable Tableflow on txp_fct_hourly_tx_metrics topic
resource "confluent_tableflow_topic" "txp_fct_hourly_tx_metrics" {
  count = local.enable_tableflow ? 1 : 0

  environment {
    id = data.terraform_remote_state.iac.outputs.confluent_environment_id
  }

  kafka_cluster {
    id = data.terraform_remote_state.iac.outputs.kafka_cluster_id
  }

  display_name = local.tableflow_topics["txp_fct_hourly_tx_metrics"]
  table_formats = ["ICEBERG"]

  byob_aws {
    bucket_name           = local.s3_bucket_name
    provider_integration_id = local.tableflow_provider_integration_id
  }

  credentials {
    key    = data.terraform_remote_state.iac.outputs.tableflow_api_key
    secret = data.terraform_remote_state.iac.outputs.tableflow_api_secret
  }

  # CRITICAL: Tableflow must be enabled AFTER DDL statement creates the table
  # This ensures the topic has a schema before Tableflow tries to materialize it
  depends_on = [
    confluent_flink_statement.ddl["txp_fct_hourly_tx_metrics"]
  ]

  lifecycle {
    prevent_destroy = false
  }
}

# Enable Tableflow on txp_dim_enriched_tx topic
resource "confluent_tableflow_topic" "txp_dim_enriched_tx" {
  count = local.enable_tableflow ? 1 : 0

  environment {
    id = data.terraform_remote_state.iac.outputs.confluent_environment_id
  }

  kafka_cluster {
    id = data.terraform_remote_state.iac.outputs.kafka_cluster_id
  }

  display_name = local.tableflow_topics["txp_dim_enriched_tx"]
  table_formats = ["ICEBERG"]

  byob_aws {
    bucket_name           = local.s3_bucket_name
    provider_integration_id = local.tableflow_provider_integration_id
  }

  credentials {
    key    = data.terraform_remote_state.iac.outputs.tableflow_api_key
    secret = data.terraform_remote_state.iac.outputs.tableflow_api_secret
  }

  # CRITICAL: Tableflow must be enabled AFTER DDL statement creates the table
  # This ensures the topic has a schema before Tableflow tries to materialize it
  depends_on = [
    confluent_flink_statement.ddl["txp_dim_enriched_tx"]
  ]

  lifecycle {
    prevent_destroy = false
  }
}
