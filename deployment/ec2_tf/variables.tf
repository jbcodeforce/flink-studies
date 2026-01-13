variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "flink-playground"
}

variable "instance_type" {
  description = "EC2 instance type (t2.micro is free-tier eligible)"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name for the SSH key pair"
  type        = string
  default     = "flink-playground-key"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instance (default: your IP only)"
  type        = string
  default     = "0.0.0.0/0" # Change to your IP for better security: "YOUR_IP/32"
}
