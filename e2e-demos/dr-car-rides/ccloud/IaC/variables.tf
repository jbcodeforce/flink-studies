# -----------------------------------------------------------------------------
# Variables — DR Car Rides Demo
# -----------------------------------------------------------------------------

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "j9r"
}

variable "aws_region_primary" {
  description = "AWS / Confluent Cloud primary region"
  type        = string
  default     = "us-west-2"
}

variable "aws_dr_region" {
  description = "AWS / Confluent Cloud region for the DR Kafka cluster and Flink pool"
  type        = string
  default     = "us-east-1"
}

