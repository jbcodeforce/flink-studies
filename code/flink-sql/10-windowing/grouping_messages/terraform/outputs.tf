output "flink_statement_names" {
  description = "Names of the created Flink statements (in execution order)"
  value = [
    confluent_flink_statement.ddl_lead_source.statement_name,
    confluent_flink_statement.ddl_bulk_leads.statement_name,
    confluent_flink_statement.faker_lead.statement_name,
    confluent_flink_statement.dml_flatten_leads.statement_name,
    confluent_flink_statement.dml_create_build_leads.statement_name,
  ]
}
