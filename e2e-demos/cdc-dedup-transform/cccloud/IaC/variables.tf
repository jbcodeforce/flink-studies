variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "flink-studies"
}

variable "bucket_name" {
  description = "S3 bucket name (must be globally unique)"
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "Allow deletion of non-empty S3 bucket"
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = false
}

variable "enable_encryption" {
  description = "Enable S3 bucket server-side encryption"
  type        = bool
  default     = true
}

variable "enable_public_access_block" {
  description = "Enable S3 bucket public access block"
  type        = bool
  default     = true
}
