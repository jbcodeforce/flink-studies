# -----------------------------------------------------------------------------
# Outputs
# txp_dim_customers Flink Statements
# -----------------------------------------------------------------------------

output "ddl_statement_id" {
  description = "ID of the DDL Flink statement"
  value       = confluent_flink_statement.ddl_txp_dim_customers.id
}

output "ddl_statement_name" {
  description = "Name of the DDL Flink statement"
  value       = confluent_flink_statement.ddl_txp_dim_customers.statement_name
}

output "dml_statement_id" {
  description = "ID of the DML Flink statement"
  value       = confluent_flink_statement.dml_txp_dim_customers.id
}

output "dml_statement_name" {
  description = "Name of the DML Flink statement"
  value       = confluent_flink_statement.dml_txp_dim_customers.statement_name
}

output "table_name" {
  description = "Name of the Flink table"
  value       = local.table_name
}
