# -----------------------------------------------------------------------------
# Raw Flink statements: deploy all .sql files in pipelines/raw/
# Requires: organization_id, environment_id, flink_compute_pool_id,
#           flink_api_key, flink_api_secret, rest_endpoint, principal_id,
#           sql_current_catalog, sql_current_database (set in variables).
# -----------------------------------------------------------------------------

locals {
  pipeline_dir   = "${path.module}/../pipelines/"
  raw_sql_files = fileset(local.pipeline_dir, "*.sql")
  base_properties = {
    "sql.current-catalog"  = var.sql_current_catalog
    "sql.current-database" = var.sql_current_database
  }
  # Inlined statement name: API requires non-empty. Prefix + filename (no .sql), underscores -> hyphens.
  raw_statement_name = {
    for f in local.raw_sql_files : f => "${coalesce(var.prefix, "stmt")}-${replace(replace(f, ".sql", ""), "_", "-")}"
  }
}



resource "confluent_flink_statement" "dotcom_commerce_salesorder_stream" {

  organization {
    id = var.organization_id
  }
  environment {
    id = var.environment_id
  }
  compute_pool {
    id = var.flink_compute_pool_id
  }
  principal {
    id = var.principal_id
  }
  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }
  rest_endpoint  = var.rest_endpoint
  statement      = file("${local.pipeline_dir}/dotcom_commerce_salesorder_stream/sql-scripts/ddl.dotcom_commerce_salesorder_stream.sql")
  statement_name = "${var.prefix}-dotcom-commerce-salesorder-stream"
  properties     = local.base_properties

  lifecycle {
    prevent_destroy = false
  }
}