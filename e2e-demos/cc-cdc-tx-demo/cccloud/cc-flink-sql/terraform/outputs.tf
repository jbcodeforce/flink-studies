# -----------------------------------------------------------------------------
# Outputs
# All Flink Statements
# -----------------------------------------------------------------------------

output "ddl_statements" {
  description = "Map of all DDL Flink statement IDs by table name"
  value = {
    for table_name, statement in confluent_flink_statement.ddl :
    table_name => {
      id   = statement.id
      name = statement.statement_name
    }
  }
}

output "dml_statements" {
  description = "Map of all DML Flink statement IDs by table name"
  value = {
    for table_name, statement in confluent_flink_statement.dml :
    table_name => {
      id   = statement.id
      name = statement.statement_name
    }
  }
}

output "all_tables" {
  description = "List of all table names being managed"
  value       = keys(local.tables)
}

# -----------------------------------------------------------------------------
# Tableflow Outputs (Conditional)
# -----------------------------------------------------------------------------
output "tableflow_topic_names" {
  description = "Tableflow-enabled topic names"
  value = {
    for k, v in {
      txp_fct_hourly_tx_metrics = try(confluent_tableflow_topic.txp_fct_hourly_tx_metrics[0].display_name, null)
      txp_dim_enriched_tx       = try(confluent_tableflow_topic.txp_dim_enriched_tx[0].display_name, null)
    } : k => v
    if v != null
  }
}

output "tableflow_topic_ids" {
  description = "Tableflow topic IDs"
  value = {
    for k, v in {
      txp_fct_hourly_tx_metrics = try(confluent_tableflow_topic.txp_fct_hourly_tx_metrics[0].id, null)
      txp_dim_enriched_tx       = try(confluent_tableflow_topic.txp_dim_enriched_tx[0].id, null)
    } : k => v
    if v != null
  }
}
