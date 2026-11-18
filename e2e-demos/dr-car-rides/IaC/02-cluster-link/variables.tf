# -----------------------------------------------------------------------------
# Variables — Layer 2 (cluster link). Everything except the first two comes from
# scripts/tfvars-from-outputs.sh 02-cluster-link (reads scripts/iac-outputs.json).
# -----------------------------------------------------------------------------

variable "cluster_link_name" {
  description = "Name of the destination-initiated cluster link"
  type        = string
  default     = "dr-rides-primary-to-dr"
}

variable "mirror_topics" {
  description = <<-EOT
    Topics mirrored to DR. Only the source, rides_raw (Layer 0). rides_clean and driver_stats are
    derived: the DR dbt deploy re-creates them from the mirrored rides_raw at failover, so
    mirroring them would pay for topics that are then dropped and rebuilt.
  EOT
  type        = list(string)
  default     = ["rides_raw"]
}

variable "primary_kafka_cluster_id" {
  type = string
}

variable "primary_bootstrap_endpoint" {
  type = string
}

variable "primary_kafka_api_key" {
  type      = string
  sensitive = true
}

variable "primary_kafka_api_secret" {
  type      = string
  sensitive = true
}

variable "dr_kafka_cluster_id" {
  type = string
}

variable "dr_rest_endpoint" {
  type = string
}

variable "dr_kafka_api_key" {
  type      = string
  sensitive = true
}

variable "dr_kafka_api_secret" {
  type      = string
  sensitive = true
}
