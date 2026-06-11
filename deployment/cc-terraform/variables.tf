variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key (also referred as Cloud API ID)"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}


variable "cloud_provider" {
  description = "Name of the cloud Provider like AWS"
  type        = string
  default     = "AWS"
}

variable "cloud_region" {
  description = "Name of the region for the cloud Provider like us-west-2"
  type        = string
  default     = "us-west-2"
}

variable "prefix" {
  description = "Prefix for resource names to avoid conflicts"
  type        = string
  default     = "j9r"
}

variable "schema_registry_id" {
  type        = string
}


variable "schema_registry_rest_endpoint" {
  type        = string
}

variable "schema_registry_api_key" {
  type        = string
  sensitive   = true
}


variable "schema_registry_api_secret" {
  type        = string
  sensitive   = true
}


variable "flink_api_key" {
  type        = string
  sensitive   = true
}


variable "flink_api_secret" {
  type        = string
  sensitive   = true
}

variable "flink_rest_endpoint" {
  type        = string
}

variable "organization_id" {
  type        = string
}

variable "environment_id" {
  type        = string
}

variable "flink_compute_pool_id" {
  type        = string
}

variable "flink_principal_id" {
  type        = string
}


