# -----------------------------------------------------------------------------
# Variables — Layer 3 (schema linking). Everything except schema_exporter_name comes from
# scripts/tfvars-from-outputs.sh 03-schema-linking (reads scripts/iac-outputs.json).
# -----------------------------------------------------------------------------

variable "schema_exporter_name" {
  description = "Name of the schema exporter (read by export-env.sh and failover-soft.sh)"
  type        = string
  default     = "j9r-schemas-to-dr"
}

variable "exported_subjects" {
  description = <<-EOT
    Exact subject names exported to DR. The primary registry is shared, so ":*:" would copy
    every project's schemas. Wildcards are not usable here: Schema Registry rejects an
    exporter whose subject list has a wildcard AND more than one entry.
    Only the source topic's subjects: the DR dbt deploy registers the schemas of rides_clean
    and driver_stats itself (DR registry is READWRITE after failover).
  EOT
  type        = list(string)
  default     = ["rides_raw-key", "rides_raw-value"]
}

variable "primary_schema_registry_id" {
  type = string
}

variable "primary_schema_registry_rest_endpoint" {
  type = string
}

variable "primary_sr_api_key" {
  type      = string
  sensitive = true
}

variable "primary_sr_api_secret" {
  type      = string
  sensitive = true
}

variable "dr_schema_registry_id" {
  type = string
}

variable "dr_schema_registry_rest_endpoint" {
  type = string
}

variable "dr_sr_api_key" {
  type      = string
  sensitive = true
}

variable "dr_sr_api_secret" {
  type      = string
  sensitive = true
}
