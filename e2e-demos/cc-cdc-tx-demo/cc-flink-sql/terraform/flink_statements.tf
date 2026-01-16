# -----------------------------------------------------------------------------
# Flink Statements
# All DDL and DML statements for dimensions, facts, and sources
# Run some alter table statements to update the cdc tables
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Local Values - Table Definitions
# -----------------------------------------------------------------------------
locals {
  # Service account ID: use variable if provided, otherwise try remote state
  # This allows step-by-step building without applying IaC changes first
  app_manager_service_account_id = coalesce(
    var.app_manager_service_account_id != "" ? var.app_manager_service_account_id : null,
    try(data.terraform_remote_state.iac.outputs.app_manager_service_account_id, null)
  )
  
  # Base properties for Flink statements
  # Use display names (not IDs) for catalog and database
  base_properties = {
    "sql.current-catalog"  = data.confluent_environment.env.display_name
    "sql.current-database" = data.confluent_kafka_cluster.cluster.display_name
  }
  
  # Define all tables with their paths and properties
  tables = {
    # Dimensions
    "txp_dim_customers" = {
      category     = "dimensions"
      ddl_path     = "../dimensions/txp/dim_customers/sql-scripts/ddl.txp_dim_customers.sql"
      dml_path     = "../dimensions/txp/dim_customers/sql-scripts/dml.txp_dim_customers.sql"
      properties_path = "../dimensions/txp/dim_customers/sql-scripts/dml.txp_dim_customers.properties"
      alter_path   = "../dimensions/txp/dim_customers/sql-scripts/alter_src_customer.sql"
      has_dml      = true
    }

  "txp_dim_enriched_tx" = {
      category     = "dimensions"
      ddl_path     = "../dimensions/txp/dim_enriched_tx/sql-scripts/ddl.txp_dim_enriched_tx.sql"
      dml_path     = "../dimensions/txp/dim_enriched_tx/sql-scripts/dml.txp_dim_enriched_tx.sql"
      properties_path = "../dimensions/txp/dim_enriched_tx/sql-scripts/dml.txp_dim_enriched_tx.properties"
      has_dml      = true
    }
  
    
    # Facts
    "txp_fct_hourly_tx_metrics" = {
      category     = "facts"
      ddl_path     = "../facts/txp/hourly_tx_metrics/sql-scripts/ddl.txp_fct_hourly_tx_metrics.sql"
      dml_path     = "../facts/txp/hourly_tx_metrics/sql-scripts/dml.txp_fct_hourly_tx_metrics.sql"
      properties_path = "../facts/txp/hourly_tx_metrics/sql-scripts/dml.txp_fct_hourly_tx_metrics.properties"
      has_dml      = true
    }
    
    # Sources
    "src_txp_transaction" = {
      category     = "sources"
      ddl_path     = "../sources/txp/src_transaction/sql-scripts/ddl.src_txp_transaction.sql"
      dml_path     = "../sources/txp/src_transaction/sql-scripts/dml.src_txp_transaction.sql"
      alter_path   = "../sources/txp/src_transaction/sql-scripts/alter_src_transactions.sql"
      properties_path = null  # No properties file exists
      has_dml      = true
    }
    
    "src_txp_pending_transaction" = {
      category     = "sources"
      ddl_path     = "../sources/txp/src_transaction/sql-scripts/ddl.src_txp_pending_transaction.sql"
      dml_path     = null
      properties_path = null
      has_dml      = false
    }
  }
  
  # Helper function to parse properties file
  parse_properties = {
    for table_name, table_config in local.tables : table_name => (
      table_config.properties_path != null && table_config.has_dml ? (
        merge(
          local.base_properties,
          {
            for line in [
              for l in split("\n", try(file(table_config.properties_path), "")) :
              trimspace(l)
              if length(trimspace(l)) > 0 && !startswith(trimspace(l), "#")
            ] :
            split("=", line)[0] => try(split("=", line)[1], "")
            if length(split("=", line)) == 2
          }
        )
      ) : local.base_properties
    )
  }
  
  # Parse ALTER statements: split by line and filter out empty lines
  # Each ALTER statement becomes a separate Flink statement
  alter_statements = {
    for table_name, table_config in local.tables :
    table_name => (
      try(table_config.alter_path, null) != null ? [
        for statement in [
          for line in split("\n", try(file(table_config.alter_path), "")) :
          trimspace(line)
          if length(trimspace(line)) > 0 && !startswith(trimspace(line), "--") && !startswith(trimspace(line), "#")
        ] :
        statement
        if length(statement) > 0
      ] : []
    )
  }
  
  # Flatten ALTER statements into a map with unique keys
  # Format: "table_name-alter-0", "table_name-alter-1", etc.
  alter_statements_flat = {
    for pair in flatten([
      for table_name, statements in local.alter_statements : [
        for idx, statement in statements : {
          key   = "${table_name}-alter-${idx}"
          table = table_name
          index = idx
          statement = statement
        }
      ]
    ]) : pair.key => pair
  }
  
  # Map table names to their ALTER statement keys (for dependency management)
  # This allows DML statements to depend on all ALTER statements for their table
  table_alter_keys = {
    for table_name, table_config in local.tables :
    table_name => [
      for key, alter_data in local.alter_statements_flat :
      key
      if alter_data.table == table_name
    ]
  }
}

# -----------------------------------------------------------------------------
# DDL Statements: Create Tables
# -----------------------------------------------------------------------------
resource "confluent_flink_statement" "ddl" {
  for_each = local.tables
  
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
  
  statement      = file(each.value.ddl_path)
  statement_name = "${var.statement_name_prefix}-ddl-${replace(each.key, "_", "-")}"
  
  properties = local.base_properties
  
  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# DML Statements: Insert Into (only for tables with DML)
# -----------------------------------------------------------------------------
resource "confluent_flink_statement" "dml" {
  for_each = {
    for table_name, table_config in local.tables :
    table_name => table_config
    if table_config.has_dml && table_config.dml_path != null
  }
  
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
  
  statement      = file(each.value.dml_path)
  statement_name = "${var.statement_name_prefix}-dml-${replace(each.key, "_", "-")}"
  
  properties = local.parse_properties[each.key]
  
  # DML statement depends on DDL being created first
  # Note: ALTER statements are optional and may be run manually, so DML doesn't depend on them
  # Execution order: DDL -> DML (ALTER can be run independently, before DML)
  depends_on = [
    confluent_flink_statement.ddl,
    # confluent_flink_statement.alter
  ]
  
  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# ALTER Statements: Modify Tables (one statement per line)
# -----------------------------------------------------------------------------
# Parse ALTER statement files and create a separate Flink statement for each line
resource "confluent_flink_statement" "alter" {
  for_each = local.alter_statements_flat
  
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
  
  statement      = each.value.statement
  statement_name = "${var.statement_name_prefix}-alter-${replace(each.value.table, "_", "-")}-${each.value.index}"
  
  properties = local.base_properties
  
  # ALTER statements depend on DDL being created first
  # Note: Using static reference to all DDL - Terraform will resolve actual dependencies
  depends_on = [
    confluent_flink_statement.ddl
  ]
  
  lifecycle {
    prevent_destroy = false
  }
}
