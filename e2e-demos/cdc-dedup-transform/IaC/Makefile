# Makefile for AWS S3 Terraform Infrastructure

.PHONY: help init plan apply destroy fmt validate clean show-outputs

# Default target
help:
	@echo "Available targets:"
	@echo "  init           - Initialize Terraform"
	@echo "  plan           - Plan Terraform changes"
	@echo "  apply          - Apply Terraform changes"
	@echo "  destroy        - Destroy Terraform resources"
	@echo "  fmt            - Format Terraform files"
	@echo "  validate       - Validate Terraform configuration"
	@echo "  show-outputs   - Show all Terraform outputs"
	@echo "  show-config    - Show Confluent Cloud S3 connector config"
	@echo "  clean          - Clean Terraform cache and state files"

# Initialize Terraform
init:
	terraform init

# Plan Terraform changes
plan:
	terraform plan

# Apply Terraform changes
apply:
	terraform apply

# Apply with auto-approve (for automation)
apply-auto:
	terraform apply -auto-approve

# Destroy Terraform resources
destroy:
	terraform destroy

# Format Terraform files
fmt:
	terraform fmt -recursive

# Validate Terraform configuration
validate: fmt
	terraform validate

# Show all outputs
show-outputs:
	terraform output

# Show Confluent Cloud S3 connector configuration
show-config:
	@echo "Confluent Cloud S3 Sink Connector Configuration:"
	@terraform output -json confluent_s3_connector_config | jq .

# Show sensitive values
show-secrets:
	@echo "Access Key ID: $(shell terraform output -raw access_key_id)"
	@echo "Secret Access Key: $(shell terraform output -raw secret_access_key)"

# Clean up Terraform cache and state files (use with caution)
clean:
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*

# Create terraform.tfvars from example if it doesn't exist
setup-vars:
	@if [ ! -f terraform.tfvars ]; then \
		cp terraform.tfvars.example terraform.tfvars; \
		echo "Created terraform.tfvars from example. Please edit it with your values."; \
	else \
		echo "terraform.tfvars already exists."; \
	fi

# Full setup for first time use
setup: setup-vars init validate plan

# Quick deployment
deploy: validate apply show-outputs
