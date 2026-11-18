# -----------------------------------------------------------------------------
# Variables — Layer 1 (DR site)
# -----------------------------------------------------------------------------

variable "prefix" {
  description = "Short prefix used in all resource display names"
  type        = string
  default     = "j9r"
}

variable "dr_region" {
  description = "AWS / Confluent Cloud region of the DR site"
  type        = string
  default     = "us-east-1"
}

variable "flink_max_cfu" {
  description = "Maximum CFUs for the DR Flink compute pool"
  type        = number
  default     = 10
}

variable "aws_profile" {
  description = "AWS CLI / SSO profile used by the aws provider (null = default credential chain)"
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR of the DR VPC that holds the PrivateLink endpoint and the bastion"
  type        = string
  default     = "10.20.0.0/16"
}

variable "bastion_instance_type" {
  description = "EC2 instance type of the SSM-only bastion"
  type        = string
  default     = "t3.small"
}

variable "outputs_parameter_name" {
  description = "Parameter Store name (SecureString) through which the bastion receives iac-outputs.json"
  type        = string
  default     = "/dr-car-rides/iac-outputs"
}

variable "flink_private_endpoint" {
  description = "Optional private Flink endpoint for the dbt dr profile (e.g. https://flink.<...>.private.confluent.cloud). Leave empty to use the public Flink API."
  type        = string
  default     = ""
}
