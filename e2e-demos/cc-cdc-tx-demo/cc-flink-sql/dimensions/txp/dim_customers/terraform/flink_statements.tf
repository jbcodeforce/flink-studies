# -----------------------------------------------------------------------------
# Flink Statements
# txp_dim_customers DDL and DML
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------
locals {
  table_name = "txp_dim_customers"
  
  # Statement names matching Makefile convention
  ddl_statement_name = "${var.statement_name_prefix}-ddl-${replace(local.table_name, "_", "-")}"
  dml_statement_name = "${var.statement_name_prefix}-dml-${replace(local.table_name, "_", "-")}"
  
  # SQL file paths (relative to terraform directory)
  ddl_script_path = "../sql-scripts/ddl.${local.table_name}.sql"
  dml_script_path = "../sql-scripts/dml.${local.table_name}.sql"
  dml_properties_path = "../sql-scripts/dml.${local.table_name}.properties"
  
  # Service account ID: use variable if provided, otherwise try remote state
  # This allows step-by-step building without applying IaC changes first
  # If neither is available, this will cause a validation error
  app_manager_service_account_id = coalesce(
    var.app_manager_service_account_id != "" ? var.app_manager_service_account_id : null,
    try(data.terraform_remote_state.iac.outputs.app_manager_service_account_id, null)
  )
  
  # Parse properties file if it exists and has content
  # Properties file format: key=value (one per line, comments start with #)
  dml_properties_raw = try(file(local.dml_properties_path), "")
  dml_properties_lines = split("\n", local.dml_properties_raw)
  dml_properties_filtered = [
    for line in local.dml_properties_lines :
    trimspace(line)
    if length(trimspace(line)) > 0 && !startswith(trimspace(line), "#")
  ]
  dml_properties_map = {
    for line in local.dml_properties_filtered :
    split("=", line)[0] => try(split("=", line)[1], "")
    if length(split("=", line)) == 2
  }
  
  # Base properties for Flink statements
  # Use display names (not IDs) for catalog and database
  base_properties = {
    "sql.current-catalog"  = data.confluent_environment.env.display_name
    "sql.current-database" = data.confluent_kafka_cluster.cluster.display_name
  }
  
  # Merge base properties with DML-specific properties
  dml_properties = merge(local.base_properties, local.dml_properties_map)
}

# -----------------------------------------------------------------------------
# DDL Statement: Create Table
# -----------------------------------------------------------------------------
resource "confluent_flink_statement" "ddl_txp_dim_customers" {
  organization {
    id = data.confluent_organization.org.id
  }
  
  environment {
    id = data.terraform_remote_state.iac.outputs.confluent_environment_id
  }
  
  compute_pool {
    id = data.terraform_remote_state.iac.outputs.flink_compute_pool_id
  }
  
  principal {
    id = local.app_manager_service_account_id
  }
  
  rest_endpoint = data.confluent_flink_region.flink_region.rest_endpoint
  
  credentials {
    key    = data.terraform_remote_state.iac.outputs.flink_api_key
    secret = data.terraform_remote_state.iac.outputs.flink_api_secret
  }
  
  statement      = file(local.ddl_script_path)
  statement_name = local.ddl_statement_name
  
  properties = local.base_properties
  
  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# DML Statement: Insert Into
# -----------------------------------------------------------------------------
resource "confluent_flink_statement" "dml_txp_dim_customers" {
  organization {
    id = data.confluent_organization.org.id
  }
  
  environment {
    id = data.terraform_remote_state.iac.outputs.confluent_environment_id
  }
  
  compute_pool {
    id = data.terraform_remote_state.iac.outputs.flink_compute_pool_id
  }
  
  principal {
    id = local.app_manager_service_account_id
  }
  
  rest_endpoint = data.confluent_flink_region.flink_region.rest_endpoint
  
  credentials {
    key    = data.terraform_remote_state.iac.outputs.flink_api_key
    secret = data.terraform_remote_state.iac.outputs.flink_api_secret
  }
  
  statement      = file(local.dml_script_path)
  statement_name = local.dml_statement_name
  
  properties = local.dml_properties
  
  # DML statement depends on DDL being created first
  depends_on = [
    confluent_flink_statement.ddl_txp_dim_customers
  ]
  
  lifecycle {
    prevent_destroy = false
  }
}
