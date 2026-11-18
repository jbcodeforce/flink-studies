output "schema_exporter_name" {
  description = "Schema exporter name (read by export-env.sh and failover-soft.sh)"
  value       = confluent_schema_exporter.primary_to_dr.name
}

output "dr_schema_registry_mode" {
  description = "Mode of the DR registry while the exporter runs"
  value       = confluent_schema_registry_cluster_mode.dr_import.mode
}
