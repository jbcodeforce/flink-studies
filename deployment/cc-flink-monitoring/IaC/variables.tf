variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key (OrganizationAdmin) for provider auth"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}

variable "prefix" {
  description = "Prefix for metrics service account and API key names"
  type        = string
  default     = "j9r"
}
