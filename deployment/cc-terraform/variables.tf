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