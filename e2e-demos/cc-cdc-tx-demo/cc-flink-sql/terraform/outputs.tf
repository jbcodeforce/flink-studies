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
